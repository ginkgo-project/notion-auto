#!/usr/bin/env bash

NOTION_PREFIX="https://api.notion.com/v1"
AUTH_HEADER="Authorization: Bearer ${NOTION_KEY}"
NOTION_VERSION="Notion-Version: 2022-06-28"
CONTENT_TYPE="Content-Type: application/json"

notion_get() {
  curl -X GET -s -H "${AUTH_HEADER}" -H "${NOTION_VERSION}" -H "${CONTENT_TYPE}" "$1"
}

notion_post() {
  curl -X POST -s -H "${AUTH_HEADER}" -H "${NOTION_VERSION}" -H "${CONTENT_TYPE}" "$1" -d "$2"
}

notion_patch() {
  curl -X PATCH -s -H "${AUTH_HEADER}" -H "${NOTION_VERSION}" -H "${CONTENT_TYPE}" "$1" -d "$2"
}
