ip address add 10.0.2.15/24 broadcast + dev ens3
ip link set dev ens3 up
ip route add 10.0.2.0/24 dev ens3
ip route add default via 10.0.2.2 dev ens3
