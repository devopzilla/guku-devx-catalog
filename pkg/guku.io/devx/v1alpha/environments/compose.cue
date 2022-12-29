package environments

import (
	"guku.io/devx/v1alpha"
	"guku.io/devx/v1alpha/components"
	composeflows "guku.io/devx/v1alpha/flows/compose"
)

Compose: v1alpha.#Environment & {
	config: {
		ingress: {
			traefik: {
				enabled: bool | *false
				expose:  bool | *true
				web: port: uint | *8080
				api: port: uint | *8081
			}
		}
	}

	flows: {
		"compose/add-service":    composeflows.#AddService
		"compose/expose-service": composeflows.#ExposeService
		"compose/expose-port":    composeflows.#ExposePort
	}

	if config.ingress.traefik.enabled {
		let T = config.ingress.traefik

		additionalComponents: {
			traefik: components.#Traefik & {
				$metadata: _
				endpoints: web: _

				traefik: {
					api: {
						enabled:  true
						insecure: true
					}
					providers: docker: enabled: true
				}

				if T.expose {
					$metadata: labels: "compose/expose-port": "\(T.web.port):\(endpoints.web.port),\(T.api.port):\(endpoints.api.port)"
				}

				$resources: compose: services: "\($metadata.id)": {
					volumes: [
						{
							type:   "bind"
							source: "/var/run/docker.sock"
							target: source
						},
					]
				}
			}
		}

		flows: "compose/add-traefik-labels": composeflows.#AddTraefikLabels
	}
}
