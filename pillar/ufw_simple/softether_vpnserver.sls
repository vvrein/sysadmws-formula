ufw_simple:
  enabled: True
  logging: 'off'
  allow:
    vpn_over_HTTPS:
      proto: 'tcp'
      to_port: '443'
    vpn_IPSec_IKE:
      proto: 'udp'
      to_port: '500'
    vpn_IPSec_NAT:
      proto: 'udp'
      to_port: '4500'
    vpn_OpenVpn_udp:
      proto: 'udp'
      to_port: '1194'
    vpn_OpenVpn_tcp:
      proto: 'tcp'
      to_port: '1194'
    vpn_SoftEther:
      proto: 'tcp'
      to_port: '5555'
cmd_check_alert:
  network:
    network_exclusions:
        softether_vpnserver: |
          --dport 1194
          --dport 500
          --dport 5555
          --dport 4500
