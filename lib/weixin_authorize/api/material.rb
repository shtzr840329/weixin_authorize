# encoding: utf-8
# 上传永久素材
module WeixinAuthorize
  module Api
    module Material

      # 目前仅仅把下载链接返回给第三方开发者，由第三方开发者处理下载
      # def download_media_url(media_id)
      #   download_media_url = WeixinAuthorize.endpoint_url("file", "#{media_base_url}/get")
      #   params = URI.encode_www_form("access_token" => get_access_token,
      #                                "media_id"     => media_id)
      #   download_media_url += "?#{params}"
      #   download_media_url
      # end

      # https://api.weixin.qq.com/cgi-bin/material/batchget_material?access_token=ACCESS_TOKEN
      # 获取永久素材列表
      def get_material_list(type, offset, count=20)
        batch_material_url = "#{material_base_url}/batchget_material"
        http_post(batch_material_url, {type: type, offset: offset, count: count})
      end


      # 新增永久图文素材
      # https://api.weixin.qq.com/cgi-bin/material/add_news?access_token=ACCESS_TOKEN
      # 上传图文消息素材, 主要用于群发消息接口
      # {
      #    "articles": [
      #      {
      #        "thumb_media_id":"mwvBelOXCFZiq2OsIU-p",
      #        "author":"xxx",
      #        "title":"Happy Day",
      #        "content_source_url":"www.qq.com",
      #        "content":"content",
      #        "digest":"digest"
      #      },
      #      {
      #        "thumb_media_id":"mwvBelOXCFZiq2OsIU-p",
      #        "author":"xxx",
      #        "title":"Happy Day",
      #        "content_source_url":"www.qq.com",
      #        "content":"content",
      #        "digest":"digest"
      #      }
      #    ]
      # }
      # Option: author, content_source_url
      def add_news(news=[])
        add_news_url = "#{material_base_url}/add_news"
        http_post(add_news_url, {articles: news})
      end

      # 更新永久图文素材
      # https://api.weixin.qq.com/cgi-bin/material/update_news?access_token=ACCESS_TOKEN
      # {
      #   "media_id":MEDIA_ID,
      #   "index":INDEX,
      #   "articles": {
      #        "title": TITLE,
      #        "thumb_media_id": THUMB_MEDIA_ID,
      #        "author": AUTHOR,
      #        "digest": DIGEST,
      #        "show_cover_pic": SHOW_COVER_PIC(0 / 1),
      #        "content": CONTENT,
      #        "content_source_url": CONTENT_SOURCE_URL
      #     }
      # }
      def update_news(media_id, index, news={})
        update_news_url = "#{material_base_url}/update_news"
        http_post(update_news_url, { media_id: media_id, index: index, articles: news } )
      end 
      
      # 新增其他类型永久素材
      # https://api.weixin.qq.com/cgi-bin/material/add_material?access_token=ACCESS_TOKEN
      def add_material(material, material_type)
        file = process_file(material)
        add_material_url = "#{material_base_url}/add_material"
        http_post(add_material_url, {media: file}, {type: material_type}, "material")
      end

      # media_id: 需通过基础支持中的上传下载多媒体文件来得到
      # https://file.api.weixin.qq.com/cgi-bin/media/uploadvideo?access_token=ACCESS_TOKEN

      # return:
      # {
      #   "type":"video",
      #   "media_id":"IhdaAQXuvJtGzwwc0abfXnzeezfO0NgPK6AQYShD8RQYMTtfzbLdBIQkQziv2XJc",
      #   "created_at":1398848981
      # }
      # def upload_mass_video(media_id, title="", desc="")
      #   video_msg = {
      #     "media_id"    => media_id,
      #     "title"       => title,
      #     "description" => desc
      #   }

      #   http_post("#{media_base_url}/uploadvideo", video_msg)
      # end

      private

        def material_base_url
          "/material"
        end

        def process_file(media)
          return media if media.is_a?(File) && jpep?(media)

          media_url = media
          uploader  = WeixinUploader.new

          if http?(media_url) # remote
            uploader.download!(media_url.to_s)
          else # local
            media_file = media.is_a?(File) ? media : File.new(media_url)
            uploader.cache!(media_file)
          end
          file = process_media(uploader)
          CarrierWave.clean_cached_files! # clear last one day cache
          file
        end

        def process_media(uploader)
          uploader = covert(uploader)
          uploader.file.to_file
        end

        # JUST ONLY FOR JPG IMAGE
        def covert(uploader)
          # image process
          unless (uploader.file.content_type =~ /image/).nil?
            if !jpep?(uploader.file)
              require "mini_magick"
              # covert to jpeg
              image = MiniMagick::Image.open(uploader.path)
              image.format("jpg")
              uploader.cache!(File.open(image.path))
              image.destroy! # remove /tmp from MinMagick generate
            end
          end
          uploader
        end

        def http?(uri)
          return false if !uri.is_a?(String)
          uri = URI.parse(uri)
          uri.scheme =~ /^https?$/
        end

        def jpep?(file)
          content_type = if file.respond_to?(:content_type)
              file.content_type
            else
              content_type(file.path)
            end
          !(content_type =~ /jpeg/).nil?
        end

        def content_type(media_path)
          MIME::Types.type_for(media_path).first.content_type
        end

    end
  end
end
