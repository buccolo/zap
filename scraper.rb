#!/usr/bin/ruby

require 'rubygems'
require 'active_support/time'
require 'nokogiri'
require 'scraperwiki'
require 'httparty'

LIMIT_DATE = Date.today - 1.days
BASE_URL = 'https://www.zapimoveis.com.br/aluguel/apartamentos/sp+sao-paulo+zona-sul+%s/?tipobusca=rapida&rangeValor=0-%s&foto=1&ord=dataatualizacao'

def get_body(url)
  HTTParty.get(url, headers: {"User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36."}).body
end

def clean_tables
	ScraperWiki::sqliteexecute("DROP TABLE IF EXISTS `swdata`")
	ScraperWiki::sqliteexecute("CREATE TABLE `swdata` (`url` text, `data` text, `total` integer, `bairro` text, `rua` text, `area` text, `dorms` text, `aluguel` text, `cond` text, `iptu` text)")
end

def get_neighborhood_url name, price
	BASE_URL % [name, price]
end

def crawl url, neighborhood, price_limit
  puts url
	doc = Nokogiri::HTML(get_body(url), nil, 'ISO-8859-1')

	doc.css('.itemOf').each do |item|
		date_str = item.css('div.itemData span').text.strip.split.last
		date = Date.strptime date_str, '%d/%m/%Y'
		break if date < LIMIT_DATE

		data = {}
		data['url'] = item.at_css('div.full a')['href']
		data['bairro'] = neighborhood
		data['data'] = date_str

		itempage = Nokogiri::HTML(get_body(data['url']), nil, 'ISO-8859-1')
		data['rua'] = itempage.at_css('span.street-address').text if itempage.at_css('span.street-address')
		itempage.css('ul.fc-detalhes li').each do |attr|
			case attr.css('span').first
				when /dormit.rios/
					data['dorms'] = attr.css('span').last.text.split.first
				when /.rea.*til/
					data['area'] = attr.css('span').last.text.gsub(/\s+/, "")
				when /condom.*/
					data['cond'] = attr.css('span').last.text.strip
				when /IPTU.*/
					data['iptu'] = attr.css('span').last.text.strip
				when /pre.* de aluguel.*/
					data['aluguel'] = attr.css('span').last.text.strip
			end
			data['total'] = 0
			['aluguel', 'cond', 'iptu'].each {|x| data['total'] += data[x].split.last.gsub('.','').to_i if data[x]}
		end

		puts data if (data['total'] < price_limit)
		ScraperWiki::save_sqlite(['url'], data) if (data['total'] < price_limit)
	end
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
