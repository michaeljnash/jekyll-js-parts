require 'fileutils'

module ConcatJS

  class << self
    attr_accessor :plugin_name, :page_scripts, :page_scripts_dir, :modules, :modules_dir
  end
  self.plugin_name = File.basename(__FILE__, '.*')
  self.page_scripts_dir = "assets/scripts/#{plugin_name}/page_scripts"
  self.modules_dir = "assets/scripts/#{plugin_name}/modules"

  class Concat < Liquid::Block

    def initialize(tag_name, input, tokens)
      @module_file, @part_id = input.split('/').map(&:strip)
      validate_module_name(@module_file)
      validate_part_id(@part_id)
      super
    end

    def render(context)

      import_str = "import \"/"+ConcatJS.modules_dir+"/"+@module_file+"\"\n"
      ConcatJS.page_scripts[context["page"]["path"]] ||= {}
      ConcatJS.page_scripts[context["page"]["path"]][@module_file] ||= import_str
      
      part_str = self.format_part(super)
      validate_unique_part(@part_id, part_str)
      ConcatJS.modules[@module_file] ||= {}
      ConcatJS.modules[@module_file][@part_id] ||= part_str
      return

    end

    private

    def validate_module_name(module_name)
      raise "Invalid output module name: #{module_name}" unless /^[a-zA-Z0-9_-]+\.js$/.match?(module_name)
    end

    def validate_part_id(part_id)
      raise "Invalid part ID: #{part_id}" unless /^[a-zA-Z0-9_-]+$/.match?(part_id)
    end

    def validate_unique_part(part_id, part_str)
      if ConcatJS.modules.values.flat_map(&:keys).include?(part_id)
        raise "Duplicate part ID: #{part_id}" if part_str != ConcatJS.modules[@module_file][@part_id]
      end
    end

    def format_part(part_str)
      self._adjust_tabbing(part_str.gsub(/<script[^>]*>|<\/script>/, '')).prepend("\n/*"+@part_id+"*/\n")
    end

    def _adjust_tabbing(part_str)
      initial = 0
      part_str.each_line.map do |line|
        initial += line.count('{') - line.count('}')
        ' ' * 4 * initial + line.strip + "\n"
      end.join.strip
    end

  end

  module Util

    def self.write_output(data_hash, dir)
      data_hash.each_pair do |path_or_name, contents|
        data = contents.values.join('') + "\n"
        path = "#{dir}/#{self.to_js_ext(path_or_name)}"
        unless File.exist?(path) && data == File.read(path)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, data)
        end
      end
    end

    def self.delete_files(directory, condition)
      Dir.glob("#{directory}/*").each do |path_or_dir|
        next unless condition.call(File.basename(path_or_dir))
        if File.file?(path_or_dir) then File.delete(path_or_dir)
        elsif !ConcatJS.page_scripts.keys.any? { |path| path.include?(File.basename(path_or_dir)) }
          FileUtils.rm_r(path_or_dir)
        end
      end
    end

    def self.to_js_ext(path)
      path.sub(/\.[^.]+\z/, '.js')
    end

  end

end

Liquid::Template.register_tag(ConcatJS.plugin_name.gsub(/([a-z]+)s\b/, '\1'), ConcatJS::Concat)

Jekyll::Hooks.register :site, :after_reset do
  FileUtils.mkdir_p(ConcatJS.page_scripts_dir) unless File.directory?(ConcatJS.page_scripts_dir)
  FileUtils.mkdir_p(ConcatJS.modules_dir) unless File.directory?(ConcatJS.modules_dir)
  ConcatJS.modules = {}
  ConcatJS.page_scripts = {}
end

Jekyll::Hooks.register :site, :post_render do
  ConcatJS::Util.write_output(ConcatJS.modules, ConcatJS.modules_dir)
  ConcatJS::Util.write_output(ConcatJS.page_scripts, ConcatJS.page_scripts_dir)

  ConcatJS.page_scripts.each_key do |page_path|
    page_script_path = File.join(ConcatJS.page_scripts_dir, ConcatJS::Util.to_js_ext(page_path))
    page_data = File.read(page_path)
    page_data.gsub!(/<script(?=[^>]*\bclass=['"]\b#{ConcatJS.plugin_name}\b['"])(?=[^>]*\btype=['"](.*?\bmodule\b.*?)['"]).*?>.*?<\/script>\s*/im, '')
    page_script_tag = "\n<script type=\"module\" class=\"#{ConcatJS.plugin_name}\" src=\"#{page_script_path}\"></script>\n"
    page_data_new = page_data.include?("<body>") ?
      page_data.sub(/(<body>)/, "\\1#{page_script_tag}") :
      page_data.sub(/(.*?---.*?---)/m, "\\1#{page_script_tag}")
    File.write(page_path, page_data_new)
  end
end

Jekyll::Hooks.register :site, :post_write do
  
  ConcatJS::Util.delete_files(ConcatJS.modules_dir, ->(file) {
    !ConcatJS.modules.keys.include?(file)
  })

  Dir.glob(ConcatJS.page_scripts_dir+"{,*/**}").select { |dir| File.directory?(dir) }.each do |dir|
    ConcatJS::Util.delete_files(dir, ->(file) {
      !ConcatJS.page_scripts.transform_keys do |key|
        ConcatJS::Util.to_js_ext(key)
      end.keys.any?{ |item| item.include?(file) } 
    })
  end

end
