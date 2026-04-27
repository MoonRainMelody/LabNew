# 基础镜像：使用包含 JDK 25 的轻量级 Alpine 镜像 (如果你前面配置的是 JDK 21，请改为 eclipse-temurin:21-jre-alpine)
FROM eclipse-temurin:25-jre-alpine

# 设置工作目录
WORKDIR /app

# 将 target 目录下的 jar 包复制到镜像内的 /app 目录下，并重命名为 app.jar
COPY target/*.jar app.jar

# 声明容器对外暴露的端口
EXPOSE 8080

# 容器启动时执行的命令
ENTRYPOINT ["java", "-jar", "app.jar"]