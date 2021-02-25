[
  {
    "name": "secrets-application",
    "image": "httpd:2.4",
    "cpu": ${app_cpu},
    "memory": ${app_memory},
    "essential": true,
    "secrets": [
      {
        "name": "PASSWORD",
        "valueFrom": "${database_password}"
      }
    ]
  }
]
