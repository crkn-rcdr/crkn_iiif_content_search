FROM ruby:3.4.1

RUN apt-get update; \
    apt-get install -y curl gnupg; \
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -; \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y nodejs npm --fix-missing
RUN npm install -g yarn@2.4.3

WORKDIR /app

COPY Gemfile .

RUN bundle install

COPY . .
#RUN yarn install
# RUN RAILS_ENV=development 
# rails vite:build
RUN bundle install --without development test

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]