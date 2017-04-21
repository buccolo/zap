#!/usr/bin/ruby

require 'rubygems'
require 'active_support/time'
require 'nokogiri'
require 'scraperwiki'
require 'httparty'
require 'uri'

def url_for(page = 1)
  URI.encode('https://www.zapimoveis.com.br/venda/apartamentos/sp+sao-paulo+zona-sul+moema/2-quartos/?#{"precomaximo":"550000","filtrodormitorios":"2;3;4;","filtrovagas":"1;2;3;4;","areautilminima":"68","areautilmaxima":"10000","possuiendereco":"True","parametrosautosuggest":[{"Bairro":"MOEMA","Zona":"Zona Sul","Cidade":"SAO PAULO","Agrupamento":"","Estado":"SP"},{"Bairro":"Vl Mariana","Zona":"Zona Sul","Cidade":"SAO PAULO","Agrupamento":"","Estado":"SP"}],"pagina":"%s","paginaOrigem":"ResultadoBusca","semente":"554920430","formato":"Lista"}' % [page])
end

def get_body(url)
  HTTParty.get(url, headers: {"User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36."}).body
end

def crawl(url)
  doc = Nokogiri::HTML(get_body(url))

  return if doc.css('.minificha').empty?

  doc.css('.minificha').each do |ap|
    price = parse(ap.css('[itemprop=price]').attr('content').text)
    cond = parse(ap.css('.preco span').text)

    data = {
      uuid: ap.attr('itemid'),
      price: price,
      cond: cond,
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

index = 1

loop do
  puts "Pagina #{index} <<<<<<<<<<<<<<<<<<<<<<<<<<"
  break unless crawl(url_for(index))

  index += 1
end
