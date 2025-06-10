package tencentcloud

import "regexp"

tag: {
	#var: {
		name:    string
		product: *"tag" | _
	}

	let N = #var.name

	#tencentcloud: tag: reqs: [key=_]: [...string]

	for k, values in #tencentcloud.tag.reqs for v in values {
		let RN = regexp.ReplaceAll("[^a-zA-Z0-9\\-_]", "\(N)_\(k)_\(v)", "_")
		resource: tencentcloud_tag: (RN): {
			tag_key:   k
			tag_value: v
		}
	}
}
