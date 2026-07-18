pipeline {
    agent {
        label 'kaniko'
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_TAG = "${env.GIT_COMMIT.take(7)}"
    }

    stages {
        stage('Build & push image (Kaniko)') {
            steps {
                container('kaniko') {
                    sh '''
                        /kaniko/executor \
                          --context="$(pwd)/app" \
                          --dockerfile="$(pwd)/app/Dockerfile" \
                          --destination="${ECR_REPOSITORY_URL}:${IMAGE_TAG}" \
                          --destination="${ECR_REPOSITORY_URL}:latest"
                    '''
                }
            }
        }

        stage('Update Helm chart & push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh '''
                        git config user.email "jenkins@ci.local"
                        git config user.name "jenkins-ci"

                        sed -i "s|^  tag:.*|  tag: ${IMAGE_TAG}|" charts/django-app/values.yaml

                        if git diff --quiet -- charts/django-app/values.yaml; then
                            echo "values.yaml already at tag ${IMAGE_TAG}, nothing to push."
                        else
                            git add charts/django-app/values.yaml
                            git commit -m "ci: bump django-app image tag to ${IMAGE_TAG} [ci skip]"

                            REPO_HOST_PATH="$(echo "${GIT_REPO_URL}" | sed 's|https://||')"
                            git push "https://${GIT_USER}:${GIT_TOKEN}@${REPO_HOST_PATH}" "HEAD:${GIT_TARGET_BRANCH}"
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
