CNF chaining using Ligato and NSM (example for LFN Webinar)
===========================================================

Overview
--------

In this simple example we demonstrate the capabilities of the NSM agent - a control-plane for Cloud-native
Network Functions deployed in Kubernetes cluster. The NSM agent seamlessly integrates [Ligato framework][ligato]
for Linux and VPP network configuration management together with [Network Service Mesh (NSM)][nsm] for separation
of data plane from control plane connectivity between containers and external endpoints.
 
In the presented use-case we simulate scenario in which a client from a local network needs to access a web server
with a public IP address. The necessary Network Address Translation (NAT) is performed in-between the client and
the web server by the high-performance [VPP NAT plugin][vpp-nat-plugin], deployed as a true CNF (Cloud-Native Network
Functions) inside a container. For simplicity the client is represented by a K8s Pod running image with [cURL][curl]
installed (as opposed to being an external endpoint as it would be in a real-world scenario). For the server side
the minimalistic [TestHTTPServer][vpp-test-http-server] implemented in VPP is utilized.

In all the three Pods an instance of NSM Agent is run to communicate with the NSM manager via NSM SDK and negotiate
additional network connections to connect the pods into a chain `client <-> NAT-CNF <-> web-server` (see diagrams below).
The agents then use the features of Ligato framework to further configure Linux and VPP networking around the additional
interfaces provided by NSM (e.g. routes, NAT).

The configuration to apply is described declaratively and submitted to NSM agents in a Kubernetes native way through
our own Custom Resource called `CNFConfiguration`. The controller for this CRD (installed by [cnf-crd.yaml][cnf-crd-yaml])
simply reflects the content of applied CRD instances into an `etcd` datastore from which it is read by NSM agents.
For example, the configuration for the NSM agent managing the central NAT CNF can be found in [cnf-nat44.yaml][cnf-nat44-yaml].  

More information about cloud-native tools and network functions provided by PANTHEON.tech can be found on our website
[cdnf.io][cdnf-io].

### Networking Diagram

![networking][networking]

### Routing Diagram

![routing][routing]

Demo steps
----------

1. Create Kubernetes cluster; deploy CNI (network plugin) of your preference
2. [Install Helm][install-helm] version 2 (latest NSM release v0.2.0 does not support Helm v3)
3. Run `helm init` to install Tiller and to set up local configuration for the Helm
4. Create service account for Tiller:
    ```
    $ kubectl create serviceaccount --namespace kube-system tiller
    $ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    $ kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
    ```   
5. Deploy NSM using Helm:
    ```
    $ helm repo add nsm https://helm.nsm.dev/
    $ helm install --set insecure=true nsm/nsm
    ```  
6. Deploy etcd + controller for CRD, both of which will be used together to pass configuration to NSM agents:
    ```
    $ kubectl apply -f cnf-crd.yaml
    ```
7. Submit definition of the network topology for this example to NSM:
    ```
    $ kubectl apply -f network-service.yaml
    ```
8. Deploy and start simple VPP-based webserver with NSM-Agent-VPP as control-plane:
    ```
    $ kubectl apply -f webserver.yaml
    ```
9. Deploy VPP-based NAT44 CNF with NSM-Agent-VPP as control-plane:
    ```
    $ kubectl apply -f cnf-nat44.yaml
    ```
10. Deploy Pod with NSM-Agent-Linux control-plane and curl for testing connection to the webserver through NAT44 CNF:
    ```
    $ kubectl apply -f client.yaml
    ```
11. Test connectivity between client and webserver:
    ```
    $ kubectl exec -it  client curl 80.80.80.80/show/version

    <html><head><title>show version</title></head><link rel="icon" href="data:,"><body><pre>vpp v20.01-rc2~11-gfce396738~b17 built by root on b81dced13911 at 2020-01-29T21:07:15
    </pre></body></html>
    ```
12. To confirm that client's IP is indeed source NATed (from `192.168.100.10` to `80.80.80.102`) before reaching
    the webserver, one can use the VPP packet tracing:
    ```
    $ kubectl exec -it webserver vppctl trace add memif-input 10
    $ kubectl exec -it client curl 80.80.80.80/show/version
    $ kubectl exec -it webserver vppctl show trace

    00:01:04:655507: memif-input
      memif: hw_if_index 1 next-index 4
        slot: ring 0
    00:01:04:655515: ethernet-input
      IP4: 02:fe:68:a6:6b:8c -> 02:fe:b8:e1:c8:ad
    00:01:04:655519: ip4-input
      TCP: 80.80.80.100 -> 80.80.80.80
    ...
    ```

[ligato]: https://ligato.io/
[nsm]: https://networkservicemesh.io/
[install-helm]: https://helm.sh/docs/intro/install/
[networking]: img/lfn-webinar-networking.png
[routing]: img/lfn-webinar-routing.png
[cdnf-io]: https://cdnf.io/
[vpp-nat-plugin]: https://wiki.fd.io/view/VPP/NAT
[curl]: https://curl.haxx.se/
[vpp-test-http-server]: https://wiki.fd.io/view/VPP/HostStack/TestHttpServer
[crd]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
[cnf-nat44-yaml]: ./cnf-nat44.yaml
[cnf-crd-yaml]: ./cnf-crd.yaml
