package aws

import "net"

ec2: {
	#var: {
		name:    string
		product: *"ec2" | _
	}

	let N = #var.name

	#aws: ec2: managed_prefix_list: {
		// define `args` for passthrough arguments
		args: _
		// define `reqs` for user input
		reqs: [family="IPv4" | "IPv6"]: [desc=_]: [...net.IPCIDR]
	}

	for family, req in #aws.ec2.managed_prefix_list.reqs {
		let RN = "\(N)_\(family)"
		resource: aws_ec2_managed_prefix_list: (RN): {
			#aws.ec2.managed_prefix_list.args
			name:           RN
			address_family: family
			// https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html
			// default quota of inbound rules per security group is 60
			// https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html#security-group-size
			// A rule that references a customer-managed prefix list counts as the maximum size of the prefix list
			max_entries: *60 | _

			entry: [for desc, cidr_blocks in req for cidr_block in cidr_blocks {
				cidr:        cidr_block
				description: desc
			}]
		}
	}

}
