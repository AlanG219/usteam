FROM openjdk:8-jre-slim
#copy war file on the container
COPY **/*.war /app/app.war
WORKDIR  /app
EXPOSE 8080
CMD [ "java", "-jar", "app.war"]
