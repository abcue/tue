package aws

sns: {
	#var: name: string

	let N = #var.name

	#aws: {
		provider: [string]: _
		sns: {
			topic: args:              _
			topic_subscription: args: _
		}
	}

	// TODO(yujunz): implement single region support without provider meta
	for rn, region in #aws.provider {
		let TN = N + "_" + region.reqs.suffix
		resource: aws_sns_topic: (TN): #aws.sns.topic.args & {
			provider: "aws.\(rn)"

			name: N
		}

		resource: aws_sns_topic_subscription: (N + "_pagerduty_" + region.reqs.suffix): #aws.sns.topic_subscription.args & {
			provider: "aws.\(rn)"

			endpoint:               #"https://events.pagerduty.com/integration/${pagerduty_service_integration.\#(N+"_aws").integration_key}/enqueue"#
			endpoint_auto_confirms: true
			protocol:               "https"
			topic_arn:              "${aws_sns_topic.\(TN).arn}"
		}
	}
}
