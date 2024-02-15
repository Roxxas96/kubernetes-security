locals {
  domain_labels = [
    "monitoring",
    "app",
    "security",
  ]
  role_labels = [
    "frontend",
    "backend",
    "database",
  ]
}

/// LABELS

resource "kubernetes_manifest" "cluster-polycy_domain-label-enforcement" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-domain-labels"
    }
    spec = {
      validationFailureAction = "Enforce"
      rules = [
        {
          name = "check-domain"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Pod"
                  ]
                }
              }
            ]
          }
          validate = {
            message = "label 'domain' is required, it can be one of: ${join(", ", local.domain_labels)}"
            pattern = {
              metadata = {
                labels = {
                  domain = "${join("|", local.domain_labels)}"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno-policies]
}

resource "kubernetes_manifest" "cluster-polycy_role-label-enforcement" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-role-labels"
    }
    spec = {
      validationFailureAction = "Enforce"
      rules = [
        {
          name = "check-role"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Pod"
                  ]
                  namespaces = [
                    kubernetes_namespace_v1.echo.metadata[0].name
                  ]
                }
              }
            ]
          }
          validate = {
            message = "label 'role' is required, it can be one of: ${join(", ", local.role_labels)}"
            pattern = {
              metadata = {
                labels = {
                  role = "${join("|", local.role_labels)}"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno-policies]
}

resource "kubernetes_manifest" "cluster-polycy_label-mutation" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "add-labels"
      annotations = {
        "policies.kyverno.io/title"       = "Add Labels"
        "policies.kyverno.io/category"    = "Sample"
        "policies.kyverno.io/minversion"  = "1.6.0"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/subject"     = "Label"
        "policies.kyverno.io/description" = "Labels are used as an important source of metadata describing objects in various ways or triggering other functionality. Labels are also a very basic concept and should be used throughout Kubernetes. This policy performs a simple mutation which adds a label `foo=bar` to Pods, Services, ConfigMaps, and Secrets."
      }
    }
    spec = {
      rules = [
        {
          name = "add-labels"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Pod",
                    "Service",
                    "ConfigMap",
                    "Secret"
                  ]
                }
              }
            ]
          }
          mutate = {
            patchStrategicMerge = {
              metadata = {
                labels = {
                  "kyverno-checked" = "true"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno-policies]
}

/// POD POLICIES

# resource "kubernetes_manifest" "cluster-polycy_pod-security" {
#   manifest = {
#     apiVersion = "kyverno.io/v1"
#     kind       = "ClusterPolicy"
#     metadata = {
#       name = "psa"
#     }
#     spec = {
#       background              = true
#       validationFailureAction = "Enforce"
#       rules = [
#         {
#           name = "restricted"
#           match = {
#             any = [
#               {
#                 resources = {
#                   kinds = [
#                     "Pod"
#                   ]
#                 }
#               }
#             ]
#           }
#           validate = {
#             podSecurity = {
#               level   = "restricted"
#               version = "latest"
#             }
#           }
#         }
#       ]
#     }
#   }

#   depends_on = [helm_release.kyverno-policies]
# }

// Create exception for kube-prometheus-stack-prometheus-node-exporter
resource "kubernetes_manifest" "exception_istio-sidears" {
  manifest = {
    apiVersion = "kyverno.io/v2beta1"
    kind       = "PolicyException"
    metadata = {
      name      = "istio-sidecars-psa"
      namespace = "${kubernetes_namespace_v1.kube-prometheus-stack.metadata.0.name}"
    }
    spec = {
      exceptions = [
        {
          policyName = "psa"
          ruleNames = [
            "restricted"
          ]
        }
      ]
      match = {
        any = [
          {
            resources = {
              kinds = [
                "DaemonSet"
              ]
              namespaces = [
                "${kubernetes_namespace_v1.kube-prometheus-stack.metadata.0.name}"
              ]
              names = [
                "kube-prometheus-stack-prometheus-node-exporter"
              ]
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.kyverno-policies]
}

resource "kubernetes_manifest" "cluster-polycy_pod-qos-guaranted" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-qos-guaranteed"
      annotations = {
        "policies.kyverno.io/title"       = "Require QoS Guaranteed"
        "policies.kyverno.io/category"    = "Other, Multi-Tenancy"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/subject"     = "Pod"
        "policies.kyverno.io/description" = "Pod Quality of Service (QoS) is a mechanism to ensure Pods receive certain priority guarantees based upon the resources they define. When Pods define both requests and limits for both memory and CPU, and the requests and limits are equal to each other, Kubernetes grants the QoS class as guaranteed which allows them to run at a higher priority than others. This policy requires that all containers within a Pod run with this definition resulting in a guaranteed QoS. This policy is provided with the intention that users will need to control its scope by using exclusions, preconditions, and other policy language mechanisms."
      }
    }
    spec = {
      validationFailureAction = "audit"
      background              = true
      rules = [
        {
          name = "guaranteed"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Pod"
                  ]
                }
              }
            ]
          }
          validate = {
            message = "All containers must define memory and CPU requests and limits where they are equal."
            foreach = [
              {
                list = "request.object.spec.containers"
                pattern = {
                  resources = {
                    requests = {
                      cpu    = "?*"
                      memory = "?*"
                    }
                    limits = {
                      cpu    = "{{element.resources.requests.cpu}}"
                      memory = "{{element.resources.requests.memory}}"
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno-policies]
}

resource "kubernetes_manifest" "cluster-polycy_disallow-latest-tag" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-latest-tag"
      annotations = {
        "policies.kyverno.io/title"       = "Disallow Latest Tag"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/minversion"  = "1.6.0"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/subject"     = "Pod"
        "policies.kyverno.io/description" = "The ':latest' tag is mutable and can lead to unexpected errors if the image changes. A best practice is to use an immutable tag that maps to a specific version of an application Pod. This policy validates that the image specifies a tag and that it is not called `latest`."
      }
    }
    spec = {
      validationFailureAction = "audit"
      background              = true
      rules = [
        {
          name = "require-image-tag"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Pod"
                  ]
                }
              }
            ]
          }
          validate = {
            message = "An image tag is required."
            pattern = {
              spec = {
                containers = [
                  {
                    image = "*:*"
                  }
                ]
              }
            }
          }
        },
        {
          name = "validate-image-tag"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Pod"
                  ]
                }
              }
            ]
          }
          validate = {
            message = "Using a mutable image tag e.g. 'latest' is not allowed."
            pattern = {
              spec = {
                containers = [
                  {
                    image = "!*:latest"
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno-policies]
}

# variable "image_public_keys" {
#   type = list(string)
# }

# resource "kubernetes_manifest" "cluster-polycy_verify-images" {
#   manifest = {
#     apiVersion = "kyverno.io/v1"
#     kind       = "ClusterPolicy"
#     metadata = {
#       name = "verify-image"
#       annotations = {
#         "policies.kyverno.io/title"       = "Verify Image"
#         "policies.kyverno.io/category"    = "Software Supply Chain Security, EKS Best Practices"
#         "policies.kyverno.io/severity"    = "medium"
#         "policies.kyverno.io/subject"     = "Pod"
#         "policies.kyverno.io/minversion"  = "1.7.0"
#         "policies.kyverno.io/description" = "Using the Cosign project, OCI images may be signed to ensure supply chain security is maintained. Those signatures can be verified before pulling into a cluster. This policy checks the signature of an image repo called ghcr.io/kyverno/test-verify-image to ensure it has been signed by verifying its signature against the provided public key. This policy serves as an illustration for how to configure a similar rule and will require replacing with your image(s) and keys."
#       }
#     }
#     spec = {
#       validationFailureAction = "enforce"
#       background = false
#       rules = [
#         {
#           name = "verify-image"
#           match = {
#             any = [
#               {
#                 resources = {
#                   kinds = [
#                     "Pod"
#                   ]
#                 }
#               }
#             ]
#           }
#           verifyImages = [
#             {
#               imageReferences = [
#                 "ghcr.io/kyverno/test-verify-image*"
#               ]
#               mutateDigest = true
#               attestors = [
#                 {
#                   entries = [
#                     {
#                       keys = {
#                         publicKeys = "${join("\n", var.image_public_keys)}"
#                       }
#                     }
#                   ]
#                 }
#               ]
#             }
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [helm_release.kyverno-policies]
# }

/// KUBE API

# apiVersion: kyverno.io/v1
# kind: ClusterPolicy
# metadata:
#   name: check-deprecated-apis
#   annotations:
#     policies.kyverno.io/title: Check deprecated APIs
#     policies.kyverno.io/category: Best Practices
#     policies.kyverno.io/subject: Kubernetes APIs
#     kyverno.io/kyverno-version: 1.7.4
#     policies.kyverno.io/minversion: 1.7.4
#     kyverno.io/kubernetes-version: "1.23"
#     policies.kyverno.io/description: >-
#       Kubernetes APIs are sometimes deprecated and removed after a few releases.
#       As a best practice, older API versions should be replaced with newer versions.
#       This policy validates for APIs that are deprecated or scheduled for removal.
#       Note that checking for some of these resources may require modifying the Kyverno
#       ConfigMap to remove filters. In the validate-v1-22-removals rule, the Lease kind
#       has been commented out due to a check for this kind having a performance penalty
#       on Kubernetes clusters with many leases. Its enabling should be attended carefully
#       and is not recommended on large clusters. PodSecurityPolicy is removed in v1.25
#       so therefore the validate-v1-25-removals rule may not completely work on 1.25+.
#       This policy requires Kyverno v1.7.4+ to function properly.      
# spec:
#   validationFailureAction: audit
#   background: true
#   rules:
#   - name: validate-v1-25-removals
#     match:
#       any:
#       - resources:
#           kinds:
#           - batch/*/CronJob
#           - discovery.k8s.io/*/EndpointSlice
#           - events.k8s.io/*/Event
#           - policy/*/PodDisruptionBudget
#           - node.k8s.io/*/RuntimeClass
#     preconditions:
#       all:
#       - key: "{{ request.operation || 'BACKGROUND' }}"
#         operator: NotEquals
#         value: DELETE
#       - key: "{{request.object.apiVersion}}"
#         operator: AnyIn
#         value:
#         - batch/v1beta1
#         - discovery.k8s.io/v1beta1
#         - events.k8s.io/v1beta1
#         - policy/v1beta1
#         - node.k8s.io/v1beta1
#     validate:
#       message: >-
#         {{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.25.
#         See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/        
#       deny: {}
#   - name: validate-v1-26-removals
#     match:
#       any:
#       - resources:
#           kinds:
#           - flowcontrol.apiserver.k8s.io/*/FlowSchema
#           - flowcontrol.apiserver.k8s.io/*/PriorityLevelConfiguration
#           - autoscaling/*/HorizontalPodAutoscaler
#     preconditions:
#       all:
#       - key: "{{ request.operation || 'BACKGROUND' }}"
#         operator: NotEquals
#         value: DELETE
#       - key: "{{request.object.apiVersion}}"
#         operator: AnyIn
#         value:
#         - flowcontrol.apiserver.k8s.io/v1beta1
#         - autoscaling/v2beta2
#     validate:
#       message: >-
#         {{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.26.
#         See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/        
#       deny: {}
#   - name: validate-v1-27-removals
#     match:
#       any:
#       - resources:
#           kinds:
#           - storage.k8s.io/*/CSIStorageCapacity
#     preconditions:
#       all:
#       - key: "{{ request.operation || 'BACKGROUND' }}"
#         operator: NotEquals
#         value: DELETE
#       - key: "{{request.object.apiVersion}}"
#         operator: AnyIn
#         value:
#         - storage.k8s.io/v1beta1
#     validate:
#       message: >-
#         {{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.27.
#         See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/        
#       deny: {}
#   - name: validate-v1-29-removals
#     match:
#       any:
#       - resources:
#           kinds:
#           - flowcontrol.apiserver.k8s.io/*/FlowSchema
#           - flowcontrol.apiserver.k8s.io/*/PriorityLevelConfiguration
#     preconditions:
#       all:
#       - key: "{{ request.operation || 'BACKGROUND' }}"
#         operator: NotEquals
#         value: DELETE
#       - key: "{{request.object.apiVersion}}"
#         operator: AnyIn
#         value:
#         - flowcontrol.apiserver.k8s.io/v1beta2
#     validate:
#       message: >-
#         {{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.29.
#         See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/        
#       deny: {}

# resource "kubernetes_manifest" "cluster-polycy_check-deprecated-api" {
#   manifest = {
#     apiVersion = "kyverno.io/v1"
#     kind       = "ClusterPolicy"
#     metadata = {
#       name = "check-deprecated-apis"
#       annotations = {
#         "policies.kyverno.io/title"       = "Check deprecated APIs"
#         "policies.kyverno.io/category"    = "Best Practices"
#         "policies.kyverno.io/subject"     = "Kubernetes APIs"
#         "kyverno.io/kyverno-version"      = "1.7.4"
#         "policies.kyverno.io/minversion"  = "1.7.4"
#         "kyverno.io/kubernetes-version"   = "1.23"
#         "policies.kyverno.io/description" = "Kubernetes APIs are sometimes deprecated and removed after a few releases. As a best practice, older API versions should be replaced with newer versions. This policy validates for APIs that are deprecated or scheduled for removal. Note that checking for some of these resources may require modifying the Kyverno ConfigMap to remove filters. In the validate-v1-22-removals rule, the Lease kind has been commented out due to a check for this kind having a performance penalty on Kubernetes clusters with many leases. Its enabling should be attended carefully and is not recommended on large clusters. PodSecurityPolicy is removed in v1.25 so therefore the validate-v1-25-removals rule may not completely work on 1.25+. This policy requires Kyverno v1.7.4+ to function properly."
#       }
#     }
#     spec = {
#       validationFailureAction = "audit"
#       background              = true
#       rules = [
#         {
#           name = "validate-v1-25-removals"
#           match = {
#             any = [
#               {
#                 resources = {
#                   kinds = [
#                     "batch/*/CronJob",
#                     "discovery.k8s.io/*/EndpointSlice",
#                     "events.k8s.io/*/Event",
#                     "policy/*/PodDisruptionBudget",
#                     "node.k8s.io/*/RuntimeClass"
#                   ]
#                 }
#               }
#             ]
#           }
#           preconditions = [
#             {
#               all = [
#                 {
#                   key      = "{{ request.operation || 'BACKGROUND' }}"
#                   operator = "NotEquals"
#                   value    = "DELETE"
#                 },
#                 {
#                   key      = "{{request.object.apiVersion}}"
#                   operator = "AnyIn"
#                   value = [
#                     "batch/v1beta1",
#                     "discovery.k8s.io/v1beta1",
#                     "events.k8s.io/v1beta1",
#                     "policy/v1beta1",
#                     "node.k8s.io/v1beta1"
#                   ]
#                 }
#               ]
#             }
#           ]
#           validate = {
#             message = "{{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.25. See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/"
#             deny    = {}
#           }
#         },
#         {
#           name = "validate-v1-26-removals"
#           match = {
#             any = [
#               {
#                 resources = {
#                   kinds = [
#                     "flowcontrol.apiserver.k8s.io/*/FlowSchema",
#                     "flowcontrol.apiserver.k8s.io/*/PriorityLevelConfiguration",
#                     "autoscaling/*/HorizontalPodAutoscaler"
#                   ]
#                 }
#               }
#             ]
#           }
#           preconditions = [
#             {
#               all = [
#                 {
#                   key      = "{{ request.operation || 'BACKGROUND' }}"
#                   operator = "NotEquals"
#                   value    = "DELETE"
#                 },
#                 {
#                   key      = "{{request.object.apiVersion}}"
#                   operator = "AnyIn"
#                   value = [
#                     "flowcontrol.apiserver.k8s.io/v1beta1",
#                     "autoscaling/v2beta2"
#                   ]
#                 }
#               ]
#             }
#           ]
#           validate = {
#             message = "{{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.26. See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/"
#             deny    = {}
#           }
#         },
#         {
#           name = "validate-v1-27-removals"
#           match = {
#             any = [
#               {
#                 resources = {
#                   kinds = [
#                     "storage.k8s.io/*/CSIStorageCapacity"
#                   ]
#                 }
#               }
#             ]
#           }
#           preconditions = [
#             {
#               all = [
#                 {
#                   key      = "{{ request.operation || 'BACKGROUND' }}"
#                   operator = "NotEquals"
#                   value    = "DELETE"
#                 },
#                 {
#                   key      = "{{request.object.apiVersion}}"
#                   operator = "AnyIn"
#                   value = [
#                     "storage.k8s.io/v1beta1"
#                   ]
#                 }
#               ]
#             }
#           ]
#           validate = {
#             message = "{{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.27. See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/"
#             deny    = {}
#           }
#         },
#         {
#           name = "validate-v1-29-removals"
#           match = {
#             any = [
#               {
#                 resources = {
#                   kinds = [
#                     "flowcontrol.apiserver.k8s.io/*/FlowSchema",
#                     "flowcontrol.apiserver.k8s.io/*/PriorityLevelConfiguration"
#                   ]
#                 }
#               }
#             ]
#           }
#           preconditions = [
#             {
#               all = [
#                 {
#                   key      = "{{ request.operation || 'BACKGROUND' }}"
#                   operator = "NotEquals"
#                   value    = "DELETE"
#                 },
#                 {
#                   key      = "{{request.object.apiVersion}}"
#                   operator = "AnyIn"
#                   value = [
#                     "flowcontrol.apiserver.k8s.io/v1beta2"
#                   ]
#                 }
#               ]
#             }
#           ]
#           validate = {
#             message = "{{ request.object.apiVersion }}/{{ request.object.kind }} is deprecated and will be removed in v1.29. See: https://kubernetes.io/docs/reference/using-api/deprecation-guide/"
#             deny    = {}
#           }
#         }
#       ]
#     }
#   }

#   depends_on = [helm_release.kyverno-policies]
# }

/// SERVICES

resource "kubernetes_manifest" "cluster-polycy_disallow-nodeport" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "restrict-nodeport"
      annotations = {
        "policies.kyverno.io/title"       = "Disallow NodePort"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/minversion"  = "1.6.0"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/subject"     = "Service"
        "policies.kyverno.io/description" = "A Kubernetes Service of type NodePort uses a host port to receive traffic from any source. A NetworkPolicy cannot be used to control traffic to host ports. Although NodePort Services can be useful, their use must be limited to Services with additional upstream security checks. This policy validates that any new Services do not use the `NodePort` type."
      }
    }
    spec = {
      validationFailureAction = "audit"
      background              = true
      rules = [
        {
          name = "validate-nodeport"
          match = {
            any = [
              {
                resources = {
                  kinds = [
                    "Service"
                  ]
                }
              }
            ]
          }
          validate = {
            message = "Services of type NodePort are not allowed."
            pattern = {
              spec = {
                type = "!NodePort"
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno-policies]
}
