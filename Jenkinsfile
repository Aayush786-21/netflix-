environment {
    DOCKER_IMAGE_NAME        = "aayush786/netflix-clone" // YOUR_DOCKERHUB_USERNAME/IMAGE_NAME
    K8S_DEPLOYMENT_FILE      = "k8s/netflix-clone-deployment.yaml"
    K8S_NAMESPACE            = "default" // Namespace where you deploy and where the secret is
    APP_LABEL                = "app=netflix-clone" // Label to select your app's pods/services
    DEPLOYMENT_NAME          = "netflix-clone"
}

parameters {
    string(name: 'TMDB_V3_API_KEY', defaultValue: '', description: 'TMDB v3 API Key required for the Docker build')
}

stages {
    stage('Cleanup Workspace') {
        steps {
            cleanWs() // Clean the workspace before starting
        }
    }

    stage('Checkout Code') {
        steps {
            git branch: 'staging', url: 'https://github.com/Aayush786-21/netflix-.git' // Replace with YOUR Git repository URL
        }
    }

    stage('Build Docker Image') {
        steps {
            script {
                if (params.TMDB_V3_API_KEY == null || params.TMDB_V3_API_KEY.trim().isEmpty()) {
                    error "TMDB_V3_API_KEY parameter is required and cannot be empty for the Docker build."
                }
                // The Dockerfile uses ARG TMDB_V3_API_KEY and ENV VITE_TMDB_V3_API_KEY=$TMDB_V3_API_KEY
                // So the key is baked into the image by Vite during the npm run build step.
                sh "docker build --build-arg TMDB_V3_API_KEY=${params.TMDB_V3_API_KEY} -t ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} -t ${env.DOCKER_IMAGE_NAME}:latest ."
            }
        }
    }

    stage('Login to Docker Hub') {
        steps {
            withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                sh "echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
            }
        }
    }

    stage('Push Docker Image to Docker Hub') {
        steps {
            sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
            sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
        }
    }

    stage('Deploy to Kind Kubernetes') {
        steps {
            script {
                withCredentials([file(credentialsId: 'kind-netflix-cluster-kubeconfig', variable: 'KUBECONFIG_PATH')]) {
                    echo "Applying Kubernetes manifests from ${env.K8S_DEPLOYMENT_FILE}..."
                    sh "kubectl --kubeconfig $KUBECONFIG_PATH apply -f ${env.K8S_DEPLOYMENT_FILE} -n ${env.K8S_NAMESPACE}"
                    
                    echo "Waiting for deployment rollout..."
                    // Timeout after 3 minutes (180s) for the rollout
                    sh "kubectl --kubeconfig $KUBECONFIG_PATH rollout status deployment/${env.DEPLOYMENT_NAME} -n ${env.K8S_NAMESPACE} --timeout=180s"
                    
                    echo "Deployment status:"
                    sh "kubectl --kubeconfig $KUBECONFIG_PATH get deployment ${env.DEPLOYMENT_NAME} -n ${env.K8S_NAMESPACE} -o wide"
                    
                    echo "Pod status:"
                    sh "kubectl --kubeconfig $KUBECONFIG_PATH get pods -n ${env.K8S_NAMESPACE} -l ${env.APP_LABEL} -o wide"
                    
                    echo "Service status:"
                    sh "kubectl --kubeconfig $KUBECONFIG_PATH get svc ${env.DEPLOYMENT_NAME}-svc -n ${env.K8S_NAMESPACE}" // Assuming service name matches deployment name + -svc
                }
            }
        }
    }
}

post {
    always {
        echo 'Pipeline finished.'
        // Logout from Docker Hub if logged in
        sh 'docker logout || true' // Use || true to not fail if not logged in

        // Clean up local Docker images (optional, good for Jenkins agent hygiene)
        script {
            try {
                sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} || true"
                sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest || true" // Be careful with rmi latest if other jobs depend on it
            } catch (err) {
                echo "Failed to remove local docker images: ${err}"
            }
        }
        deleteDir() // Clean up workspace again
    }
    success {
        echo 'Pipeline succeeded!'
        // Add any success notifications here (e.g., email, Slack)
    }
    failure {
        echo 'Pipeline failed!'
        // Add any failure notifications here
    }
}
