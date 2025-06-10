package aws

import (
	"strings"
	"list"
)

route53: {
	#var: name: string

	#aws: route53: {
		ns: [_=string]: string | *[...string]
	}

	let N = #var.name
	let RN = strings.Replace(#var.name, ".", "_", -1)

	provider: aws: region: *"us-east-1" | _

	resource: aws_route53_zone?: (RN): {}

	data: aws_route53_zone: (RN): {
		name: N
	}

	for n, v in #aws.route53.ns {
		resource: aws_route53_record: (strings.Replace(n, ".", "_", -1) + "_ns"): {
			zone_id: "${data.aws_route53_zone.\(RN).zone_id}"
			name:    n
			type:    "NS"
			records: list.FlattenN([v], -1)
			ttl: *300 | _
		}
	}
}
