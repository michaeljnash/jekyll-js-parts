# Jekyll js-parts
A simple Jekyll plugin that allow js partials to be included anywhere, and bundles according to pages the scripts are used in, utilising es modules.

The idea is that you can include js partials within the html of your _includes (or elsewhere), which will then be bundled and added to the appropriate pages automatically on each render. Each page will only import the javascript required on said page. All you have to do is use the liquid tags for your js partials, the rest is automatic.

Good for highly coupled javascript to some html that would make sense / be easier to be beside your html for more maintainable code.

The liquid tag structure is:
```{% js_part output_module_file.js/part_id %}```

Example:
```
{% js_part header.js/log_helloworld %}
  <script>
    console.log("hello world!");
  </script>
{% endjs_part %}
```
