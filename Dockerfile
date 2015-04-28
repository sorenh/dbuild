FROM <%= flavor %>:<%= dist %>
MAINTAINER Rohan Garg <rohan@garg.io>

RUN apt-get update && apt-get -y install pbuilder \
                                         devscripts \
                                         aptitude \
                                         build-essential \
                                         ruby

RUN useradd -m buildd
