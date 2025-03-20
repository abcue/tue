package account

import "github.com/abcue/tue/providers/tencentcloud"

terraform: required_providers: tencentcloud: source: "tencentcloudstack/tencentcloud"

#tencentcloud: {
	private_dns: domain: *"default.doma.in" | _
	vpc: reqs: {
		vpc_name:          *"default" | _
		subnet_name:       *"default" | _
		availability_zone: *"ap-guangzhou-1" | _
	}
}

tencentcloud.with.rsc_id
