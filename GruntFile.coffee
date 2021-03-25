module.exports = (grunt) ->

	grunt.initConfig
		watch:
			options:
				livereload: 23333
				dateFormat: (time) ->
					grunt.log.writeln "The watch finished in #{ time }ms at#{ new Date().toString() }"
					grunt.log.writeln 'Waiting for more changes...'
			forCoffee:
				files: [
					'./src/**/*.coffee'
				]
				tasks: ['newer:coffee', 'newer:uglify', 'newer:copy']
		
		coffee:
			options:
				sourceMap: false
				bare: true
			default:
				files: [
					expand: true
					cwd: './src'
					src: ['*.coffee']
					dest: './dist'
					ext: '.js'
				]

		uglify:
			options:
				beautify: true
				#mangle: false
				#preserveComments: false
				output:
					comments: false
				#compress:
					#drop_console: true

			default:
				files: [
					expand: true
					cwd: './dist'
					src: ['*.js']
					dest: './dist'
				]

		copy:
			default:
				files: [
					expand: true
					cwd: './dist'
					src: ['**']
					dest: '../rain-mp/src/libs'
				]

	# 任务加载
	require('load-grunt-tasks') grunt, scope: 'devDependencies'

	grunt.registerTask 'default', ['coffee', 'uglify', 'copy', 'watch']
