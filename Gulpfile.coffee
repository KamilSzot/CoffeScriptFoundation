gulp    = require "gulp"
plugin  = (require "gulp-load-plugins")()
es      = require "event-stream"
runSequence = require "run-sequence"
del     = require "del"

out = -> es.map (file, next) ->
  console.log file.history.reverse().join(" <- ")
  next(null, file)

compileCoffee = (stream) ->
  justCoffee = plugin.filter '**/*.coffee'
  stream.pipe justCoffee
    .pipe plugin.plumber()
    .pipe plugin.sourcemaps.init()
    .pipe plugin.coffee()
    .pipe plugin.sourcemaps.write()
    .pipe plugin.rename { dirname: 'js' }
    .pipe justCoffee.restore()

copyHtml = (stream) ->
  justHtml   = plugin.filter '**/*.html'
  stream.pipe justHtml
    .pipe justHtml.restore()

compileLess = (stream) ->
  justLess   = plugin.filter '**/*.less'
  stream.pipe justLess
    .pipe plugin.less()
    .pipe plugin.rename { dirname: 'css' }
    .pipe justLess.restore()

optimizeCss = (stream) ->
  justCss   = plugin.filter '**/*.css'
  stream.pipe justCss
    .pipe plugin.concat 'styles.css'
    .pipe plugin.uncss({ html: ['src/index.html'] })
    .pipe plugin.cssmin()
    .pipe plugin.rename { dirname: 'css', suffix: '.min' }
    .pipe justCss.restore()

optimizeAll = (stream) ->
    stream = optimizeCss stream

prepareAll = (stream) ->
  stream = copyHtml stream
  stream = compileCoffee stream
  stream = compileLess stream
  stream = optimizeCss stream

saveAll = (target, stream) ->
  stream
    .pipe gulp.dest(target)
    .pipe out()
    .on 'error', plugin.util.log

gulp.task 'build', [], ->
  del.sync 'build'
  stream = gulp.src 'src/*'
  stream = prepareAll stream
  stream = saveAll 'build', stream

gulp.task 'dist', [], ->
  del.sync 'dist'
  stream = gulp.src 'src/*'
  stream = prepareAll stream
  stream = optimizeAll stream
  stream = saveAll 'dist', stream


gulp.task 'watch', [], ->
  plugin.livereload.listen()
  stream = plugin.watch 'src/*.coffee', { emitOnGlob: false }
  stream = prepareAll stream
  stream = saveAll 'build', stream
    .pipe plugin.livereload()

gulp.task 'connect', [], ->
  plugin.connect.server
    root: 'build'


gulp.task 'default', (done) ->
  runSequence 'build', 'connect', 'watch', done
