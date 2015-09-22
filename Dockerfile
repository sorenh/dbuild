FROM <%= flavor %>:<%= dist %>
MAINTAINER Rohan Garg <rohan@garg.io>

RUN mkdir -p /usr/lib/pbuilder

ADD pbuilder-satisfydepends* /usr/lib/pbuilder/

RUN apt-get update && apt-get -y install aptitude build-essential

RUN useradd -m buildd
