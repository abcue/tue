package tencentcloud

import (
	"strings"
	"net"
)

vpc: {
	#var: {
		product: "vpc"
		name:    string
	}

	let N = #var.name

	#tencentcloud: {
		vpc: {
			args: _
			reqs: {
				nat_gateway?: _
				// subnets -> name -> cidr -> availability zone
				subnets: [NAME=string]: [net.IPCIDR]: string
			}
		}
		address: {
			// https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/address_template
			template: [NAME=string]: _
			// https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/address_template_group
			template_group: [NAME=string]: _
		}
	}

	resource: tencentcloud_vpc: (N): {
		name: N
		#tencentcloud.vpc.args
	}

	resource: tencentcloud_private_dns_record: "\(N)_vpc": {
		zone_id:      "${local.zone_id}"
		sub_domain:   "\(N).vpc"
		ttl:          300
		record_type:  "TXT"
		record_value: "${tencentcloud_vpc.\(N).id}"
	}

	for n, subnet in #tencentcloud.vpc.reqs.subnets for cidr, az in subnet {
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

	if #tencentcloud.vpc.reqs.nat_gateway != _|_ {
		let NG = "\(N)_vpc"

		resource: tencentcloud_nat_gateway: (NG): {
			name:                NG
			vpc_id:              "${tencentcloud_vpc.\(N).id}"
			nat_product_version: 2
			assigned_eip_set: [
				"${tencentcloud_eip.\(NG)_eip.public_ip}",
			]
		}

		resource: "tencentcloud_eip": "\(NG)_eip": {
			name: NG
		}

		resource: tencentcloud_route_table_entry: "\(NG)_route": {
			route_table_id:         "${tencentcloud_vpc.\(N).default_route_table_id}"
			destination_cidr_block: "0.0.0.0/0"
			next_type:              "NAT"
			next_hub:               "${tencentcloud_nat_gateway.\(NG).id}"
		}
	}

	for n, t in #tencentcloud.address.template {
		resource: tencentcloud_address_template: (n): t & {
			name: n
		}
		resource: tencentcloud_private_dns_record: "\(n)_ipm": {
			zone_id:      "${local.zone_id}"
			sub_domain:   "\(n).ipm"
			ttl:          300
			record_type:  "TXT"
			record_value: "${tencentcloud_address_template.\(n).id}"
		}
	}
}
