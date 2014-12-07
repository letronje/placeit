require 'net/http'
require 'rest_client'
require 'htmlentities'
require "mechanize"

namespace :country_data do
	desc "collect country info"
	task collect_country_info: :environment do 
# 		@countries = Oj.load(File.read("locations.json"))	
		@countries = {}
		get_flag_and_map
		get_highest_points
		get_national_anthem
		get_heads_of_country
			landmarks
		@countries
		File.open("locations.json", "w") { |file| file.write Oj.dump(@countries) }
	end
	
  def get_flag_and_map
		response = RestClient.get 'https://www.kimonolabs.com/api/cgbme00k?apikey=BurxkWv91mNJOoZNjd33mgvdzHgKNBVy'
# 		response =  '{
#  	"results": {
#     "collection1": [
#       {
#         "name": {
#           "href": "http://en.wikipedia.org/wiki/Algeria",
#           "text": "Algeria"
#         },
#         "flag": {
#           "src": "http://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Flag_of_Algeria.svg/50px-Flag_of_Algeria.svg.png",
#           "alt": "Algeria",
#           "href": "http://en.wikipedia.org/wiki/Algeria",
#           "text": ""
#         },
#         "Capital": {
#           "href": "http://en.wikipedia.org/wiki/Algiers",
#           "text": "Algiers"
#         },
#         "currency": {
#           "href": "http://en.wikipedia.org/wiki/Dinar",
#           "text": "Dinar"
#         },
#         "official languages": {
#           "href": "http://en.wikipedia.org/wiki/Arabic",
#           "text": "Arabic"
#         }
#       }]
#     }
#   }'
		response = Oj.load(response)

		response["results"]["collection1"].each do |country_data|
			puts country_data
			name = country_data["name"]["text"].split("[")[0]
			next if is_blank? name 
			country = { 
				name: name,
				wiki_url: country_data["name"]["href"],
				flag: country_data["flag"]["src"],			
				capital: { name: country_data["Capital"]["text"],
									 wiki: country_data["Capital"]["href"]
									},
				currency: { name: country_data["currency"]["text"],
										wiki: country_data["currency"]["href"]
									}
			}
				
			if country_data["official languages"].is_a? Array
				country[:official_languages] = country_data["official languages"].map{|a|
					a["text"] 
					}.join(", ")
			else
				country[:official_languages] = country_data["official languages"]["text"]
			end
			puts country
			@countries[name.parameterize.underscore.to_sym] = country
		end
		@countries
	end
	
  def get_highest_points
		response = RestClient.get 'https://www.kimonolabs.com/api/aypadpcq?apikey=BurxkWv91mNJOoZNjd33mgvdzHgKNBVy'
# 		response = ' 
# 		{ "results": {
# 				"collection1": [
# 					{
# 						"name": {
# 							"href": "http://en.wikipedia.org/wiki/Nepal",
# 							"text": "Nepal"
# 						},
# 						"peak_or_mountain": {
# 							"href": "http://en.wikipedia.org/wiki/Mount_Everest",
# 							"text": "Mount Everest"
# 						},
# 						"height": {
# 							"href": "http://en.wikipedia.org/wiki/#cite_note-elev-1",
# 							"text": "8,848 m (29,029 ft)[1]"
# 						},
# 						"world rank of the peak": "1",
# 						"fact": {
# 							"href": "http://en.wikipedia.org/wiki/Earth",
# 							"text": "Highest point (i.e. elevation) on Earth."
# 						}
# 					}
# 				]
# 			}
# 		}'
		response = Oj.load(response)

		response["results"]["collection1"].each do |country_data|
			name = country_data["name"]["text"].split("[")[0]
			next if is_blank? name 
			cntry_sym = name.parameterize.underscore.to_sym
			country = @countries[cntry_sym] || {}
			country[:name] = non_blank country[:name], name
			country[:wiki_url] = non_blank country[:wiki_url], country_data["name"]["href"] 	
			country[:highest_peak] = {
				name: country_data["peak_or_mountain"]["text"],
				url: country_data["peak_or_mountain"]["href"],
				height: country_data["height"]["text"].split("[")[0],
				rank_in_world: country_data["world rank of the peak"],
				note: country_data["fact"]["text"]
			}
			@countries[cntry_sym] = country
		end
		@countries
	end
	
	def get_national_anthem
		response = RestClient.get 'https://www.kimonolabs.com/api/cvp3n88a?apikey=BurxkWv91mNJOoZNjd33mgvdzHgKNBVy'
# 		response = '{
# 			 "results": {
# 				"collection1": [
# 					{
# 						"name": {
# 							"href": "http://en.wikipedia.org/wiki/Afghanistan",
# 							"text": "Afghanistan"
# 						},
# 						"national_anthem": {
# 							"href": "http://en.wikipedia.org/wiki/Afghan_National_Anthem",
# 							"text": "\"Millī Surūd\"\n(\"National Anthem\")"
# 						},
# 						"national_anthem_aud": {
# 							"href": "http://en.wikipedia.org/wiki/File:National_anthem_of_Afghanistan.ogg",
# 							"text": "\"Millī Surūd\""
# 						}
# 					}
# 				]
# 			}
# 		}'
		response = Oj.load(response)
		response["results"]["collection1"].each do |country_data|
			name = country_data["name"]["text"].split("[")[0]
			next if is_blank? name 
			cntry_sym = name.parameterize.underscore.to_sym
			country = @countries[cntry_sym] || {}
			country[:name] = non_blank country[:name], name
			country[:wiki_url] = non_blank country[:wiki_url], country_data["name"]["href"] 	
			anthem = country_data["national_anthem"]["text"].split("[")[0]
			country[:national_anthem] = {
				name: anthem,
				wiki: country_data["national_anthem"]["href"],
				audio: country_data["national_anthem_aud"]["href"]
			}
			@countries[cntry_sym] = country
		end
		@countries
	end
	
	def get_heads_of_country
	response = RestClient.get 'https://www.kimonolabs.com/api/ejy36x4m?apikey=BurxkWv91mNJOoZNjd33mgvdzHgKNBVy'
# 		response = '{
# 			"results": {
# 			"collection1": [
# 					{
# 						"name": {
# 							"href": "http://en.wikipedia.org/wiki/Afghanistan",
# 							"text": "Afghanistan"
# 						},
# 						"head_of_state": [
# 							"President - Ashraf Ghani",
# 							"Prime Minister - Abdullah Abdullah"
# 						]
# 					}
# 	    	]
# 			}
# 		}'
		response = Oj.load(response)
		response["results"]["collection1"].each do |country_data|
			name = country_data["name"]["text"].split("[")[0]
			next if is_blank? name 
			cntry_sym = name.parameterize.underscore.to_sym
			country = @countries[cntry_sym] || {}
			country[:name] = non_blank country[:name], name
			country[:wiki_url] = non_blank country[:wiki_url], country_data["name"]["href"] 	
			country[:heads_of_state] = country_data["head_of_state"]
			@countries[cntry_sym] = country
		end
		@countries
	end

	def landmarks_and_images
	response = RestClient.get 'https://www.kimonolabs.com/api/d9j9lt3w?apikey=BurxkWv91mNJOoZNjd33mgvdzHgKNBVy&kimbypage=1&kimbysource=1'
# 		response = '{
# 			"results": {
# 			"collection1": [
# 					{
# 						"name": {
# 							"href": "http://en.wikipedia.org/wiki/Afghanistan",
# 							"text": "Afghanistan"
# 						},
# 						"head_of_state": [
# 							"President - Ashraf Ghani",
# 							"Prime Minister - Abdullah Abdullah"
# 						]
# 					}
# 	    	]
# 			}
# 		}'
		response = Oj.load(response)
		response["results"]["collection1"].each do |country_data|
			name = country_data["name"]["text"].split("[")[0]
			next if is_blank? name 
			cntry_sym = name.parameterize.underscore.to_sym
			country = @countries[cntry_sym] || {}
			country[:name] = non_blank country[:name], name
			country[:wiki_url] = non_blank country[:wiki_url], country_data["name"]["href"] 	
			country[:heads_of_state] = country_data["head_of_state"]
			@countries[cntry_sym] = country
		end
		@countries
	end


	def landmarks
		country_urls = RestClient.get 'https://www.kimonolabs.com/api/e9qa41ce?apikey=BurxkWv91mNJOoZNjd33mgvdzHgKNBVy'
		country_urls = Oj.load(country_urls)["results"]["countries"]
		country_urls.each do |url|
			url = url["url"]
			puts url
			response = RestClient.get url
			page = Nokogiri::HTML(response)
			name = page.xpath("//*[@id='content']/h1").text
			puts name
			next if is_blank? name 
			cntry_sym = name.parameterize.underscore.to_sym
			country = @countries[cntry_sym] || {}
			puts country
			for i in 1..3 do
				puts i
				heading_parts = page.xpath("//*[@id='content']/div[1]/h2[#{i}]").text.split(" ")
				puts heading_parts
				cat = heading_parts.map(&:camelize) & ["Cities", "Landmarks", "Facts"]
				puts cat
				if(cat.size > 0)
					temp = []
					cat_name = cat.join(" ").parameterize.underscore.to_sym
					puts cat_name
					page.xpath("//*[@id='content']/div[1]/div[#{i}]/div").each do |a|
						entry = {}
						entry[:name] = a.text
						entry[:img_src] = a.xpath("h3/a/img")[0].attributes["src"].value  if !a.xpath("h3/a/img")[0].nil?
						ap entry
						temp << entry
					end
					country[cat_name] = temp	
					puts country
					@countries[cntry_sym] = country	
				end
			end
		end
	end

	def non_blank var, val
		(is_blank? var) ? val : var
	end
	
	def is_blank? var
		!(!var.nil? && !var.blank?)
	end
end
