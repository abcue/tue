package aws

import "strings"

cloudwatch: {
	#var: name: string
	let N = #var.name

	#aws: {
		provider: [region=string]: _
		cloudwatch: {
			metric_alarm: reqs: [region=_]: {
				[service=_]: [resource=_]: [metric=_]: [when=_]: args: {
					// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm
					alarm_name: strings.Join([service, resource, metric, when, "\(threshold)"], "_")
					// Metric
					namespace:   "AWS/\(strings.ToUpper(service))"
					metric_name: metric
					dimensions:  _
					statistic:   "Average"
					period:      300
					// Condition
					comparison_operator: when
					threshold:           number
					// Additional
					evaluation_periods: 1
					// Actions
					alarm_actions: _
					ok_actions:    _
					// Others
					tags: app: N
				}

				sqs: [queue=_]: [metric=_]: [when=_]: args: dimensions: QueueName: queue

				rds: [instance=_]: [metric=_]: [when=_]: args: dimensions: {
					DBInstanceIdentifier: instance
					DBClusterIdentifier?: _
				}
			}
		}
	}

	for rgn, svcs in #aws.cloudwatch.metric_alarm.reqs for rscs in svcs for metrics in rscs for when in metrics for it in when {
		// aws cloudwatch set-alarm-state --alarm-name rds-stage-instance-1_CPUUtilization_GreaterThanThreshold_80 --state-reason "Testing the Amazon Cloudwatch alarm" --state-value ALARM --region us-west-2
		resource: aws_cloudwatch_metric_alarm: {
			(it.args.alarm_name + "_" + rgn): {
				provider: "aws.\(rgn)"
				it.args
				alarm_actions: ["${aws_sns_topic.\(N+"_"+#aws.provider[rgn].reqs.suffix).arn}"]
				ok_actions: ["${aws_sns_topic.\(N+"_"+#aws.provider[rgn].reqs.suffix).arn}"]
			}
		}
	}
}
