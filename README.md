[![Code Climate](https://codeclimate.com/github/sul-dlss/content_search/badges/gpa.svg)](https://codeclimate.com/github/sul-dlss/content_search)
[![Code Climate Test Coverage](https://codeclimate.com/github/sul-dlss/content_search/badges/coverage.svg)](https://codeclimate.com/github/sul-dlss/content_search/coverage)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fcontent_search.svg)](https://badge.fury.io/gh/sul-dlss%2Fcontent_search)

# Content Search

Content Search provides a IIIF Content Search 0.9 API endpoint for "search-within" or "highlights-in-context" for digital object OCR.

Content Search will index an item when someone runs a search in sul-embed/Mirador.  Content Search listens to Kafka to invalidate it's cache when an object changes.

## Requirements

1. Ruby (2.3.0 or greater)
2. [bundler](http://bundler.io/) gem

## Installation

Clone the repository

    $ git clone git@github.com:sul-dlss/content_search.git

Move into the app and install dependencies

    $ cd content_search
    $ bundle install

Start the development server

    $ rails s

## Configuring

Configuration is handled through the [RailsConfig](/railsconfig/config) `settings.yml` files.


# Configuration

This repo is configured to pull and run solr through docker compose, and has the data folder mapped as a volume, which will allow the solr index to be created automatically for you, and will persist the information in the index for development or production needs.

For CRKN in production, we are using a solr instance running independantly from this docker compose. To configure the Solr instance to work with the Blacklight container, I sshed onto the Solr server, and performed the following:

Connect to the solr vm:

`ssh -i ~/.ssh/<id file>.pem <user>@4.204.49.142`

Created the content_search core config directory:
`sudo mkdir /opt/bitnami/solr/server/solr/content_search/`
`sudo mkdir /opt/bitnami/solr/server/solr/content_search/conf`

Copied the default configs to my new core:

`sudo cp -r /opt/bitnami/solr/server/solr/configsets/_default/conf/* /opt/bitnami/solr/server/solr/content_search/conf/`

Went into the new core's config directory:

`cd /opt/bitnami/solr/server/solr/content_search/conf/`

Removed the default solr config:

`sudo rm solrconfig.xml`

Pasted the solrconfig from this repo into a new solrconfig file:

`sudo vi solrconfig.xml`

Removed the default solr schema:

`sudo rm managed-schema.xml`

Pasted the solr schema from this repo into a new solr schema file:

`sudo vi managed-schema.xml`

Restarted solr to apply the changes:

`sudo /opt/bitnami/ctlscript.sh restart solr`


A quick command to clear the solr index is:

`curl -X POST -H 'Content-Type: application/json' 'http://username:password@host/solr/content_search/update?commit=true' -d '{ "delete": {"query":"*:*"} }'`

#### Local Configuration

The defaults in `config/settings.yml` should work on a locally run installation.

## Testing

The test suite (with RuboCop style enforcement) will be run with the default rake task (also run on travis)

    $ bundle exec rake

The specs can be run without RuboCop style enforcement

    $ bundle exec rspec

The RuboCop style enforcement can be run without running the tests

    $ bundle exec rubocop

## Running Solr

In a new terminal window:

```bash
$ bundle exec solr_wrapper
```

## Indexing content


```ruby
> Search.client.commit
```
