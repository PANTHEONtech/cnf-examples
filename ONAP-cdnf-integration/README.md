# Using ONAP (CDS component) to configure Pantheon.tech Firewall CNF

This example contains demonstration of how to use CDS (Controller Design Studio)
to configure Pantheon.tech Firewall CNF. It will also show that used configuration 
will result in behaviour change of Firewall CNF (firewall will block/allow actual 
traffic).

## Requirements
1. docker (tested with 20.10.5) 
2. docker-compose (tested with 1.27.4)
3. curl (tested with 7.68.0 (x86_64-pc-linux-gnu))

Tested on Ubuntu 20.04
## How to run demonstration
You can run the demonstration by using script:
```
./run-demo.sh
```
### Setup part of script
- Containers start - The script will start some CDS containers, Firewall CNF and some containers for 
simulating traffic through Firewall CNF (startpoint, endpoint containers).
- Data plane - The script will configure path from startpoint to endpoint container through VPP
inside Firewall CNF using VETH tunnels. This will be the data plane of the 
Firewall CNF usage use case.
- Control plane - The script will also configure the CDS to use Firewall CNF as configurable piece of software.
This will be the control plane of the Firewall CNF usage use case. To configure 
CDS, self-contained service must be defined. The self-contained service will be
defined as CBA (Controller Blueprint Archive) zip file. Its content is in `cba` 
directory and it was hand made (CDS has UI that can be reached at https://127.0.0.1:3000/ 
when cds-ui container is running, but it is not mature enough to create full 
functional CBA yet). The script will create archive out of it (make zip archive) and register
it with CDS runtime (Note: this process is more complicated due to the need of CBA enrichment -
process of extracting dependent models/definition from CDS runtime database into CBA zip file
to achive full self-containment of all information in one archive).
### Demostration part of script
Script will perform demonstrative traffic by pinging endpoint container from startpoint container 
going through Firewall CNF when:
1. Firewall CNF is not configured
2. Firewall CNF is configured by CDS (call of CDS triggers configuration of Firewall CNF) to Deny traffic
3. Firewall CNF is configured by CDS to Allow traffic

## Alternative Demonstration
You can also just use the script to create the docker containers and use 
- the postman collection instead of curl command in script
- connect into startpoint and endpoint docker containers using linux cmd line 
  and show traffic by hand (ping + tcpdump)
  
## CBA development
The CBA can be developed with any text editor and then validated against running CDS runtime by registering 
it (demo script does this). However, if you prefer maven, you can use provided `pom.xml` in `cba` directory 
and do with
```
mvn clean install -Pdeploy-cba
```
all these things at once:
- compile scripts
- run linters on scripts
- run tests on scripts (can ignore test and their compilation by using 
  `-DskipTests -Dmaven.test.skip=true`)
- pack it all into CBA archive and automatically deploy it into CDS runtime

Note that you need to setup references to ONAP maven repositories, to download all necessary artifacts.

For more information about CBA see [CBA related onap wiki](https://wiki.onap.org/pages/viewpage.action?pageId=59965554#ModelingConcepts-ControllerBlueprintArchive). 