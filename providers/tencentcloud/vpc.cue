package product

import (
	"strings"
	"net"
)

vpc: {
	#var: {
		name:       string
		cidr_block: net.IPCIDR
		// subnets -> name -> cidr -> availability zone
		subnets: [NAME=string]: [net.IPCIDR]: string
		nat_gateway_enabled: bool | *false
	}

	let N = #var.name

	resource: tencentcloud_vpc: (N): {
		name:       N
		cidr_block: #var.cidr_block
	}

	resource: tencentcloud_private_dns_record: "\(N)_vpc": {
		zone_id:      "${local.zone_id}"
		sub_domain:   "\(N).vpc"
		ttl:          300
		record_type:  "TXT"
		record_value: "${tencentcloud_vpc.\(N).id}"
	}

	for n, subnet in #var.subnets for cidr, az in subnet {
		let S = strings.Join([N, n, az], "_")
		resource: tencentcloud_subnet: (S): {
			name:              n
			vpc_id:            "${tencentcloud_vpc.\(N).id}"
			cidr_block:        cidr
			availability_zone: az
		}

		resource: tencentcloud_private_dns_record: "\(S)_subnet": {
			zone_id:      "${local.zone_id}"
			sub_domain:   "\(S).subnet"
			ttl:          300
			record_type:  "TXT"
			record_value: "${tencentcloud_subnet.\(S).id}"
		}
	}

	if #var.nat_gateway_enabled {
		resource: "tencentcloud_eip": "\(N)_nat_gateway_eip1": {
			name: "\(N)_nat_gateway_eip1"
		}

		resource: tencentcloud_nat_gateway: "\(N)_nat_gateway": {
			name:                "\(N)_nat_gateway"
			vpc_id:              "${tencentcloud_vpc.\(N).id}"
			nat_product_version: 2
			assigned_eip_set: [
				"${tencentcloud_eip.\(N)_nat_gateway_eip1.public_ip}",
			]
		}

		resource: tencentcloud_route_table_entry: "\(N)_nat_gateway_route": {
			route_table_id:         "${tencentcloud_vpc.\(N).default_route_table_id}"
			destination_cidr_block: "0.0.0.0/0"
			next_type:              "NAT"
			next_hub:               "${tencentcloud_nat_gateway.\(N)_nat_gateway.id}"
		}
	}
}
