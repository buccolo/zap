#!/usr/bin/ruby

require 'rubygems'
require 'active_support/time'
require 'nokogiri'
require 'scraperwiki'
require 'httparty'

BASE_URL = 'https://www.zapimoveis.com.br/aluguel/apartamentos/sp+sao-paulo+zona-sul+%s/?tipobusca=rapida&rangeValor=0-%s&foto=1&ord=dataatualizacao'.freeze

def get_body(url)
  HTTParty.get(url, headers: {"User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36."}).body
end

def clean_tables
  ScraperWiki::sqliteexecute("DROP TABLE IF EXISTS `swdata`")
  ScraperWiki::sqliteexecute("CREATE TABLE `swdata` (`url` text, `data` text, `total` integer, `bairro` text, `rua` text, `area` text, `dorms` text, `aluguel` text, `cond` text, `iptu` text)")
end

def get_neighborhood_url(name, price)
  BASE_URL % [name, price]
end

def crawl(url, neighborhood, price_limit)
  doc = Nokogiri::HTML(get_body(url))

  doc.css('.minificha').each do |ap|
    rent = parse(ap.css('[itemprop=price]').attr('content').text)
    cond = parse(ap.css('.preco span').text)
    total_price = cond + rent

    data = {
      uuid: ap.attr('itemid'),
      total_price: total_price,
      address: ap.css('[itemprop=streetAddress]').text,
      quartos: parse(ap.css('[class=icone-quartos]').text),
      vagas: parse(ap.css('[class=icone-vagas]').text),
      area: parse(ap.css('[class=icone-area]').text.split("m2").last),
      url: url
    }

    puts data
    ScraperWiki::save_sqlite([:uuid], data)
  end
end

def parse(text)
  text.split(': ').last.to_s.gsub(/[R\$\ \.]/, '').to_i
end

bairros = [
  'vl-mariana',
  'vl-olimpia',
  'moema'
]

clean_tables

price = 3500
bairros.each do |n|
  url = get_neighborhood_url(n, price)
  crawl url, n, price
end
