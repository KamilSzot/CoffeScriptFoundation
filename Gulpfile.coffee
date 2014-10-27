gulp    = require "gulp"
plugin  = (require "gulp-load-plugins")()
es      = require "event-stream"
runSequence = require "run-sequence"
del     = require "del"

out = -> es.map (file, next) ->
  console.log file.history.reverse().join(" <- ")
  next(null, file)

pass = (arg, funcs...) ->
  for fn in funcs
    arg = fn arg
  arg

curry = (fn, args...) ->
  (rest...) ->
    fn.apply @, args.concat rest


compileCoffee = (stream) ->
  stream
    .pipe justCoffee = plugin.filter('**/*.coffee')
    .pipe plugin.plumber()
    .pipe plugin.sourcemaps.init()
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
    compileCoffee
    compileLess

saveAll = (target, stream) ->
  stream
    .pipe gulp.dest(target)
    .pipe out()
    .on 'error', plugin.util.log

gulp.task 'build', [], ->
  del.sync ['build']
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
