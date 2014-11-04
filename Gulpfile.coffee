gulp    = require "gulp"
plugin  = (require "gulp-load-plugins")()
es      = require "event-stream"
runSequence = require "run-sequence"
del     = require "del"

browserify = require "browserify"
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'
moduleDeps = require 'module-deps'
concatStream = require 'concat-stream'
streamReduce = require 'stream-reduce'
highland = require 'highland'

q = require 'q'

out = -> es.map (file, next) ->
  # console.log file.history.reverse().join(" <- ")
  console.log file
  next(null, file)

pass = (arg, funcs...) ->
  for fn in funcs
    arg = fn arg
  arg

curry = (fn, args...) ->
  (rest...) ->
    fn.apply @, args.concat rest



browserifyCoffee = (stream) ->
  stream
    .pipe justCoffee = plugin.filter('**/*.coffee')
    .pipe es.map (file, next) ->
      console.log file.path
      browserify(file.path, {
        debug : true, # !gulp.env.production,
        extensions: ['.csjx', '.coffee']
        fullPaths: true,
        bundleExternal: false
      }).external('jquery').transform('coffee-reactify').bundle().pipe(source('js/app.js')).pipe(buffer()).pipe(es.map (file)-> next(null, file))

    # .pipe plugin.rename({ extname: '.cjsx' })
    # .pipe out()
    .pipe justCoffee.restore()


compileCoffee = (stream) ->
  stream
    .pipe justCoffee = plugin.filter('**/*.coffee')
    .pipe plugin.plumber()
    .pipe plugin.sourcemaps.init()
    .pipe plugin.coffeeReactTransform()
    .pipe plugin.coffee()
    .pipe plugin.sourcemaps.write()
    .pipe plugin.rename({ dirname: 'js' })
    .pipe justCoffee.restore()

copyHtml = (stream) ->
  stream
    .pipe justHtml   = plugin.filter('**/*.html')
    .pipe justHtml.restore()

compileLess = (stream) ->
  stream
    .pipe justLess   = plugin.filter('**/*.less')
    .pipe plugin.sourcemaps.init()
    .pipe plugin.less()
    .pipe plugin.sourcemaps.write()
    .pipe plugin.rename({ dirname: 'css' })
    .pipe justLess.restore()

concatLess = (stream) ->
  stream
    .pipe justLess   = plugin.filter('**/*.less')
    .pipe plugin.concat('all.less')
    .pipe justLess.restore()

optimizeCss = (stream) ->
  stream
    .pipe justCss    = plugin.filter('**/*.css')
    .pipe plugin.concat('css/app.css')
    .pipe plugin.uncss({ html: ['src/index.html'] })
    .pipe plugin.cssmin()
    # .pipe plugin.rename({ dirname: 'css', suffix: '.min' })
    .pipe justCss.restore()

optimizeJs = (stream) ->
  stream
    .pipe justJs     = plugin.filter('**/*.js')
    .pipe plugin.concat('js/app.js')
    .pipe plugin.jsmin()
    .pipe justJs.restore()

optimizeAll = (stream) ->
  pass stream,
    optimizeCss
    optimizeJs

prepareAll = (stream) ->
  pass stream,
    copyHtml
    browserifyCoffee
    compileLess

saveAll = (target, stream) ->
  stream
    .pipe gulp.dest(target)
    .pipe out()
    .on 'error', plugin.util.log

gulp.task 'build', ['build-externals'], ->
  # del.sync ['build']
  pass gulp.src('src/*'),
    prepareAll
    curry saveAll, 'build'

gulp.task 'dist', [], ->
  del.sync 'dist'
  pass gulp.src('src/*'),
    concatLess
    prepareAll
    optimizeAll
    curry saveAll, 'dist'


gulp.task 'watch', [], ->
  plugin.livereload.listen()
  stream = pass plugin.watch('src/*', { emitOnGlob: false }),
    prepareAll
    curry saveAll, 'build'

  stream
    .pipe out()
    .pipe plugin.livereload()

gulp.task 'connect', [], ->
  plugin.connect.server
    root: 'build'


gulp.task 'default', (done) ->
  runSequence 'build', 'connect', 'watch', done

detective = require "detective"
fs = require "fs"

gulp.task 'test', (done) ->
  plugin.watch('src/*.coffee', { read: false })
    .pipe(out())
    # .pipe(es.writeArray((err, arr) -> console.log arr; done()))
    .pipe es.map (file, next) ->
      npmDeps gulp.src file.path
        .toArray (deps) ->
          console.log deps



npmDeps = (stream) ->
  isLocal = (id) -> /^(\.\/|\.\.\/|\/)/.test(id)
  stream
    .pipe(es.map (file, next) -> next(null, file.path ))
    .pipe moduleDeps transform: 'coffee-reactify', extensions: ['.coffee', '.js'], filter: isLocal
    .pipe highland()
    .flatMap (file, next) ->
      highland(Object.keys(file.deps))
        .filter (id) -> ! isLocal id

gulp.task 'build-source', (taskDone) ->
  npmDeps(gulp.src('./src/*.coffee', { read: false })).toArray (deps) ->
    b = browserify({
      entries: ['./src/app.coffee'],
      debug: false,
      extensions: ['.coffee']
    })
    b.transform({}, 'coffee-reactify')
    b.external(deps)
    b.bundle()
        .pipe(source("app.js"))
        .pipe(buffer())
        .pipe gulp.dest('build/js')
        .on 'end', taskDone

gulp.task 'build-externals', (taskDone) ->
  npmDeps(gulp.src('./src/*.coffee', { read: false }))
    .pipe es.writeArray (err, deps) ->
        console.log deps
        b = browserify({
          entries: deps
          # fullPaths: true,
          # debug: false,
          extensions: ['.coffee']
        })
        b.transform({}, 'coffee-reactify')
        b.require(deps)
        b.bundle()
          .pipe(source("ext.js"))
          .pipe(buffer())
          .pipe gulp.dest('build/js')
          .on 'end', taskDone

  # d = b.pipeline.get('emit-deps')
  # d.on('data', (args...)-> console.log args)
  # deps = [];
  # d.push(es.map (file, next) ->
  #   if !file.entry && file.file.indexOf('node_modules') >= 0
  #     next(null, file)
  #   else
  #     deps.push(file.deps)
  #     next(null)
  # )
