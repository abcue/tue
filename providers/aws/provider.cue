package aws

import "strings"

provider: {
	// Multiple providers for different regions
	#aws: provider: [region=string]: reqs: suffix: strings.Replace(region, ".", "_", -1)
	provider: aws: [
		// Default region
		{
			region: *"us-east-1" | _
		},
		for rgn, _ in #aws.provider {
			{
				region: rgn
				alias:  rgn
			}
		},
	]
}
