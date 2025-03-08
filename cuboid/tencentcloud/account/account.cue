package account

import "github.com/abcue/tue/providers/tencentcloud"

#var: {
	private_dns: domain: *"default.doma.in" | _
	args: {
		vpc_name:          *"default" | _
		subnet_name:       *"default" | _
		availability_zone: *"ap-guangzhou-1" | _
	}
}

tencentcloud.with.rsc_id
