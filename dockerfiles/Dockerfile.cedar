FROM fabiokung/cedar
MAINTAINER hone

COPY docker_support/install-jdk.sh /tmp/install-jdk.sh
ENV STACK=cedar
RUN bash /tmp/install-jdk.sh "1.8"
ENV PATH=/opt/jdk/.jdk/bin:$PATH

RUN cd /opt && curl http://apache.org/dist/maven/maven-3/3.3.1/binaries/apache-maven-3.3.1-bin.tar.gz -s -o - | tar xzf - && ln -s /opt/apache-maven-3.3.1/bin/mvn /usr/local/bin

# setup workspace
RUN rm -rf /tmp/workspace
RUN mkdir -p /tmp/workspace

# output dir is mounted
COPY build.sh /tmp/build.sh
CMD ["sh", "/tmp/build.sh", "/tmp/workspace", "/tmp/output", "/tmp/cache"]
