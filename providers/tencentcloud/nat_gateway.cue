package tencentcloud

import "strings"

nat_gateway: {
	#var: name: string
	#tencentcloud: {
		vpc: reqs: vpc_name: string
		nat_gateway: {
			reqs: {
				assigned_eips: [{
					bandwidth: int | *100
					snat_rules_source_cidr?: [...string]
				}, ...]
				tags: [string]: string | *{
					created_by: "terraform"
				}
			}
			args: {
				nat_product_version: int | *2
				max_concurrent:      int | *1000000
				bandwidth:           int | *100
				...
			}
		}
	}
	let N = #var.name
	let VPC_ID = "${local.rsc_id[\"\(strings.ToLower(#tencentcloud.vpc.reqs.vpc_name)).vpc\"]}"

	// Create EIPs for NAT Gateway
	for i, eip in #tencentcloud.nat_gateway.reqs.assigned_eips {
		let eip_index = i + 1
		resource: tencentcloud_eip: "\(N)_eip_\(eip_index)": {
			name:                       "\(N)_nat_gateway_eip_\(eip_index)"
			internet_max_bandwidth_out: eip.bandwidth
			tags:                       #tencentcloud.nat_gateway.reqs.tags
		}
	}

	// Create NAT Gateway
	resource: tencentcloud_nat_gateway: (N): #tencentcloud.nat_gateway.args & {
		name:   N
		vpc_id: VPC_ID
		assigned_eip_set: [
			for i, eip in #tencentcloud.nat_gateway.reqs.assigned_eips {
				let eip_index = i + 1
				#"${tencentcloud_eip.\#(N)_eip_\#(eip_index).public_ip}"#
			},
		]
		tags: #tencentcloud.nat_gateway.reqs.tags
	}

	data: tencentcloud_vpc_route_tables: default: {
		vpc_id: VPC_ID
		name:   "default"
	}

	// Add default route to NAT Gateway
	resource: tencentcloud_route_table_entry: "\(N)_default_route": {
		route_table_id:         #"${data.tencentcloud_vpc_route_tables.default.instance_list[0].route_table_id}"#
		destination_cidr_block: "0.0.0.0/0"
		next_type:              "NAT"
		next_hub:               "${tencentcloud_nat_gateway.\(N).id}"
	}

	// Store NAT Gateway ID in DNS for reference
	resource: tencentcloud_private_dns_record: "\(N)_nat_gateway": {
		zone_id:      "${local.zone_id}"
		sub_domain:   "\(N).nat_gateway"
		ttl:          300
		record_type:  "TXT"
		record_value: "${tencentcloud_nat_gateway.\(N).id}"
	}

	output: {
		tencentcloud: {
			value: {
				nat_gateway_id: "${tencentcloud_nat_gateway.\(N).id}"
				eip_list: [
					for i, eip in #tencentcloud.nat_gateway.reqs.assigned_eips {
						let eip_index = i + 1
						"${tencentcloud_eip.\(N)_eip_\(eip_index).public_ip}"
					},
				]
			}
		}
	}
}
