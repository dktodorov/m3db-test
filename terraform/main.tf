resource "google_container_cluster" "my" {
  name               = "test-cluster"
  location           = "europe-west3-c"

  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "my_preemptible_nodes" {
  name               = "test-cluster"
  location           = "europe-west3-c"
  cluster    = google_container_cluster.my.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "n1-standard-2"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "google_compute_address" "ip_address1" {
  name = "prometheus-m3db-ip"
}

resource "google_compute_address" "ip_address2" {
  name = "prometheus-ip"
}

resource "google_compute_address" "ip_address3" {
  name = "grafana-ip"
}
