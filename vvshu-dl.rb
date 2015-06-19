#!/usr/bin/env ruby

#vvshu-dl
#version 0.1

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'ruby-progressbar'
require 'fileutils'
require 'net/http'
require 'rmagick' #For conversion to PDF
require 'colorize'

#Magazine class that contains methods for parsing, downloading, and formatting magazines from VVSHU
class Magazine

	@@base_url = "http://img1.vvshu.com/" #vvshu image server

	def initialize(web_url)
		@web_url = web_url
		@page = get_page	
		@directory = get_dir
		@mag_id = get_mag_id
		@page_num = get_page_num.to_i
		@filetype = get_filetype
		@foldername = @mag_id+"/"+get_foldername
	end

	public

		#Returns information about the magazine currently downloading
		def info 
			"Magazine ID: %s\nDirectory: %s\nPages: %d\nFiletype: %s\nFolder Name: %s\n" % [@mag_id,@directory,@page_num,@filetype,@foldername]
		end

		#Get array of image urls in proper format (IMG001,IMG002,etc...)
		def get_url_array
			url_array = []
			for i in (1..@page_num)
				url_array << (@@base_url + @directory + "%03d" % i + @filetype)
			end
			return url_array
		end

		#Multithreaded downloader of the images
		#http://andrey.chernih.me/2014/05/29/downloading-multiple-files-in-ruby-simultaneously/
		def download_net_http(thread_count)

			FileUtils.mkdir_p (@foldername)	#Create Directory if does not exist
			
			progressbar = ProgressBar.create(	#Initialize progressbar (with pacman character ᗧᗧᗧᗧᗧ)
				:format => 'Downloading %a %bᗧ%i %p%% %t',
				:progress_mark  => ' ',
				:remainder_mark => '･',
	            :starting_at    => 0,
	            :total => @page_num,
	            :autofinish => false)
			
			queue = Queue.new
			urls = get_url_array
			urls.map { |url| queue << url }
			
			threads = thread_count.times.map do
			Thread.new do
				Net::HTTP.start('img1.vvshu.com', 80) do |http| #Initiate persistent connection to image server, increases performance
					while !queue.empty? && url = queue.pop
					uri = URI(url)
					request = Net::HTTP::Get.new(uri)
					response = http.request request
					File.write("./#{@foldername}/#{url.split("/")[-1]}", response.body) #write response to image file
					progressbar.increment
					end
				end
			end
		end
			threads.each(&:join)
			progressbar.finish
		end

		def convert_to_pdf
			puts "Converting to PDF..."
			images = Dir["#{@foldername}/*#{@filetype}"]
			pdf_image_list = ::Magick::ImageList.new
			pdf_image_list.read(*images) 

			pdf_image_list.write("#{@foldername}/#{get_foldername}.pdf")
		end

		def delete_images
			puts "Deleting images..."
			FileUtils.rm Dir["./#{@foldername}/*#{@filetype}"]

		end

	private

		def get_page #Gets data inside of a <script> tag containing metadata about the magazine
			Nokogiri::HTML(open(@web_url)).xpath("/html/body/script[2]")[0].to_s
		end

		def get_dir #Returns the location of where the images are stored
			@page.split('var dir = ')[1].split(';')[0].gsub(/\s|"|'/, '')
		end

		def get_mag_id #Returns the name of the magazine used online
			@web_url.split("vvshu.com/view/")[1].split('/')[0].gsub(/\s|"|'/, '')
		end

		def get_page_num #Returns number of pages
			@page.split('var page = ')[1].split(';')[0].gsub(/\s|"|'/, '')
		end

		def get_filetype #Returns filetype of the online images
			@page.split('var gs = ')[1].split(';')[0].gsub(/\s|"|'/, '')
		end

		def get_foldername #Generate a foldername in the format of 
			if get_dir.split("/")[1].include?("_")
				return get_dir.split("/")[1]
			else
				return get_dir.split("/")[1]+"_"+get_dir.split("/")[0]
			end
		end

end

if ARGV.size == 0 #print usage if script is run without arguments
	puts "Usage: #{$0} url1 url2 ..."
else
	ARGV.each do |mag|
		begin
			magazine = Magazine.new(mag)
			puts magazine.info
			magazine.download_net_http(100)
			magazine.convert_to_pdf
			magazine.delete_images
		rescue  
		 	puts 'Unable to download magazine! (check the url?)'
		end  
		puts 'Done!'
	end
end
