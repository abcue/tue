package account

import "github.com/abcue/tue/providers/tencentcloud"

#tencentcloud: dnspod: {
	domain: "dnspod.domain"
	sub_domains: [
		"subdomain1",
		"subdomain2",
		"subdomain3",
	]
}

tencentcloud.dnspod
