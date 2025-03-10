package account

import "github.com/abcue/tue/providers/tencentcloud"

#var: dnspod: {
	domain: "dnspod.domain"
	sub_domains: [
		"subdomain1",
		"subdomain2",
		"subdomain3",
	]
}

tencentcloud.dnspod
