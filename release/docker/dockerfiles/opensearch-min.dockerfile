# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.
#
# Modifications Copyright OpenSearch Contributors. See
# GitHub history for details.

# Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.


# This dockerfile generates an AmazonLinux-based image containing an OpenSearch installation.
# It assumes that the working directory contains the following files:
#   opensearch-min.tgz
#   log4j2.properties
#   opensearch.yml
#   opensearch-min-docker-entrypoint.sh
# Build arguments:
#   VERSION: Required. Used to label the image.
#   BUILD_DATE: Required. Used to label the image. Should be in the form 'yyyy-mm-ddThh:mm:ssZ', i.e. a date-time from https://tools.ietf.org/html/rfc3339. The timestamp must be in UTC.
#   UID: Optional. Specify the opensearch userid. Defaults to 1000.
#   GID: Optional. Specify the opensearch groupid. Defaults to 1000.
#   OPENSEARCH_HOME: Optional. Specify the opensearch root directory. Defaults to /usr/share/opensearch.


########################### Stage 0 ########################
FROM amazonlinux:2 AS linux_x64_stage_0

ARG UID=1000
ARG GID=1000
ARG OPENSEARCH_HOME=/usr/share/opensearch

# Update packages
# Install the tools we need: tar and gzip to unpack the OpenSearch tarball, and shadow-utils to give us `groupadd` and `useradd`.
RUN yum update -y && yum install -y tar gzip shadow-utils && yum clean all

# Create an opensearch user, group, and directory
RUN groupadd -g $GID opensearch && \
    adduser -u $UID -g $GID -d $OPENSEARCH_HOME opensearch && \
    mkdir /tmp/opensearch

# Prepare working directory
COPY opensearch-min.tgz /tmp/opensearch/opensearch-min.tgz
RUN tar -xzf /tmp/opensearch/opensearch-min.tgz -C $OPENSEARCH_HOME --strip-components=1
COPY opensearch-min-docker-entrypoint.sh $OPENSEARCH_HOME/
COPY log4j2.properties opensearch.yml $OPENSEARCH_HOME/config/


########################### Stage 1 ########################
# Copy working directory to the actual release docker images
FROM amazonlinux:2

ARG UID=1000
ARG GID=1000
ARG OPENSEARCH_HOME=/usr/share/opensearch

# Update packages
# Install the tools we need: tar and gzip to unpack the OpenSearch tarball, and shadow-utils to give us `groupadd` and `useradd`.
RUN yum update -y && yum install -y tar gzip shadow-utils && yum clean all

# Create an opensearch user, group
RUN groupadd -g $GID opensearch && \
    adduser -u $UID -g $GID -d $OPENSEARCH_HOME opensearch

# Copy from Stage0
COPY --from=linux_x64_stage_0 $OPENSEARCH_HOME $OPENSEARCH_HOME
WORKDIR $OPENSEARCH_HOME

RUN chown -R $UID:$GID $OPENSEARCH_HOME

# Change user
USER $UID

# Expose ports for the opensearch service (9200 for HTTP and 9300 for internal transport)
EXPOSE 9200 9300

ARG VERSION
ARG BUILD_DATE

# Label
LABEL org.label-schema.schema-version="1.0" \
  org.label-schema.name="opensearch-min" \
  org.label-schema.version="$VERSION" \
  org.label-schema.url="https://opensearch.org" \
  org.label-schema.vcs-url="https://github.com/OpenSearch" \
  org.label-schema.license="Apache-2.0" \
  org.label-schema.vendor="Amazon" \
  org.label-schema.build-date="$BUILD_DATE"

# CMD to run
CMD ["./opensearch-min-docker-entrypoint.sh"]
