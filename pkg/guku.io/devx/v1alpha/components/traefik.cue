package components

import (
	"strconv"
	"strings"
	"guku.io/devx/v1alpha"
	"guku.io/devx/v1alpha/traits"
)

#Traefik: v1alpha.#Component & {
	traits.#Workload
	traits.#Exposable

	traefik: {
		api: {
			enabled:  bool | *false
			insecure: bool | *false
		}
		providers: {
			docker: {...}
		}
		entrypoints: {
			web: address: string | *":80"
			api: address: string | *":8080"
		}
	}

	containers: default: {
		image: "traefik"
		env: {
			// api config
			"TRAEFIK_API":          "\(traefik.api.enabled)"
			"TRAEFIK_API_INSECURE": "\(traefik.api.insecure)"

			// providers
			for id, provider in traefik.providers {
				"TRAEFIK_PROVIDERS_\(strings.ToUpper(id))": "\(provider.enabled)"
			}
		}
	}

	endpoints: {
		for id, entrypoint in traefik.entrypoints {
			"\(id)": port: uint | *strconv.ParseUint(strings.Split(entrypoint.address, ":")[1], 10, 16)
		}
	}
}
