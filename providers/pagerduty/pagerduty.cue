package pagerduty

import "regexp"

all_in_one: {
	#var: name: string

	let N = #var.name

	#pagerduty: {
		reqs: subdomain: string
		team: {
			reqs: {
				name?: string
				id:    *"${data.pagerduty_team.\(N).id}" | _
				if args.name != _|_ {
					id: "${pagerduty_team.\(N).id}"
				}
			}
			args: name?: _
		}
		user: reqs: {
			owner: string
			members: [id=string]: _
		}
		service: {
			args: {}
			reqs: [svc=string]: owner: _
		}
		schedule: args: {}
		// // Failed to create via terraform
		// slack_connection?: {
		// 	[_]: args: {
		// 		workspace_id: string
		// 		channel_id:   string
		// 		...
		// 	}
		// 	team?:    _
		// 	service?: _
		// }
	}

	terraform: required_providers: pagerduty: source: "pagerduty/pagerduty"

	if #pagerduty.team.args.name != _|_ {
		resource: pagerduty_team: (N): #pagerduty.team.args
	}

	if #pagerduty.team.reqs.name != _|_ {
		data: pagerduty_team: (N): {
			name: #pagerduty.team.reqs.name
		}
	}

	for n, svc in #pagerduty.service.reqs {
		resource: pagerduty_service: (n): {
			#pagerduty.service.args
			name:              n
			escalation_policy: "${pagerduty_escalation_policy.\(n).id}"
		}

		let U = regexp.ReplaceAll("[\\.@]", svc.reqs.owner, "_")

		data: pagerduty_user: (U): {
			email: svc.reqs.owner
		}

		resource: pagerduty_escalation_policy: (n): {
			name: n
			rule: {
				escalation_delay_in_minutes: 30
				target: {
					id:   "${pagerduty_schedule.\(N).id}"
					type: "schedule_reference"
				}
			}
			teams: [#pagerduty.team.reqs.id]
		}
	}

	resource: pagerduty_event_orchestration: (N): {
		name: N
		team: #pagerduty.team.reqs.id
	}

	resource: pagerduty_event_orchestration_router: (N): {
		event_orchestration: "${pagerduty_event_orchestration.\(N).id}"

		catch_all: actions: {
			route_to: "${pagerduty_service.\(N).id}"
		}

		set: [{
			id: "start"
			rule: {
				disabled: false
				label:    N
				actions: route_to:     "${pagerduty_service.\(N).id}"
				condition: expression: "event.summary matches '\(N)'"
			}
		}]
	}

	resource: pagerduty_service: (N): {
		#pagerduty.service.args
		name:              N
		escalation_policy: "${pagerduty_escalation_policy.\(N).id}"
	}

	for id, user in #pagerduty.user.reqs.members {
		let U = regexp.ReplaceAll("[\\.@]", id, "_")
		data: pagerduty_user: (U): {
			email: id
		}

		resource: pagerduty_team_membership: "\(N)_\(U)": user.args & {
			team_id: #pagerduty.team.reqs.id
			user_id: "${data.pagerduty_user.\(U).id}"
		}
	}

	resource: pagerduty_escalation_policy: (N): {
		name: N
		rule: {
			escalation_delay_in_minutes: 30
			target: {
				id:   "${pagerduty_schedule.\(N).id}"
				type: "schedule_reference"
			}
		}
		teams: [#pagerduty.team.reqs.id]
	}

	data: pagerduty_user: (N): {
		email: #pagerduty.user.reqs.owner
	}

	resource: pagerduty_service_integration: (N): {
		name:    N
		type:    "generic_events_api_inbound_integration"
		service: "${pagerduty_service.\(N).id}"
	}

	resource: pagerduty_service_integration?: (N + "_aws")?: {
		name:    N + "_aws"
		type:    "event_transformer_api_inbound_integration"
		service: "${pagerduty_service.\(N).id}"
	}

	resource: pagerduty_service_integration?: (N + "_email")?: {
		name:    N + "_email"
		type:    "generic_email_inbound_integration"
		service: "${pagerduty_service.\(N).id}"
	}

	resource: pagerduty_schedule: (N): {
		#pagerduty.schedule.args
		name:      N
		time_zone: *"Etc/UTC" | _
		layer: [{
			name:                         N
			start:                        "2025-04-22T18:40:00+08:00"
			rotation_virtual_start:       "2025-04-22T18:40:00+08:00"
			rotation_turn_length_seconds: 604800 // 1 week
			users: [
				"${data.pagerduty_user.\(N).id}",
			]
			restriction: {
				type:              "daily_restriction"
				start_time_of_day: "09:00:00"
				duration_seconds:  32400
			}
		}]
		teams: [#pagerduty.team.reqs.id]
	}

	// Failed to create via terraform
	if #pagerduty.slack_connection != _|_ {
		resource: pagerduty_slack_connection: [_]: {
			notification_type: "responder"
			config: {
				events: [
					"incident.triggered",
					"incident.acknowledged",
					"incident.escalated",
					"incident.resolved",
					"incident.reassigned",
					"incident.annotated",
					"incident.unacknowledged",
					"incident.delegated",
					"incident.priority_updated",
					"incident.responder.added",
					"incident.responder.replied",
					"incident.status_update_published",
					"incident.reopened",
				]
			}
			workspace_id: string
			channel_id:   string
		}

		if #pagerduty.slack_connection.service != _|_ {
			resource: pagerduty_slack_connection?: (N + "_service"): #pagerduty.slack_connection.service.args & {
				source_id:   "${pagerduty_service.\(N).id}"
				source_type: "service_reference"
			}
		}

		if #pagerduty.slack_connection.team != _|_ {
			resource: pagerduty_slack_connection?: (N + "_team"): #pagerduty.slack_connection.team.args & {
				source_id:   #pagerduty.team.reqs.id
				source_type: "team_reference"
			}
		}
	}

	output: urls: value: {
		orchestration:     "https://\(#pagerduty.reqs.subdomain).pagerduty.com/event-orchestration/${pagerduty_event_orchestration.\(N).id}"
		service:           "${pagerduty_service.\(N).html_url}"
		integration:       "${pagerduty_service_integration.\(N).html_url}"
		escalation_policy: "https://\(#pagerduty.reqs.subdomain).pagerduty.com/escalation_policies/${pagerduty_escalation_policy.\(N).id}"
		schedule:          "https://\(#pagerduty.reqs.subdomain).pagerduty.com/schedules/${pagerduty_schedule.\(N).id}"
	}
}
