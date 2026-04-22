sudo config vlan add 100
sudo config vlan member add -u 100 Ethernet4
sudo config vlan add 200
sudo config vlan member add -u 200 Ethernet8
sudo config vxlan add vtep 10.0.1.1
sudo config vxlan evpn_nvo add nvo vtep
sudo config vxlan map add vtep 100 1000
sudo config vxlan map add vtep 200 2000