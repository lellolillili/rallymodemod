angular.module('beamng.apps')
    .directive('pnotes', ['$filter', '$log', '$state', '$rootScope', function ($filter, $log, $state, $rootScope) {
        return {
            templateUrl: '/ui/modules/apps/pnotes/app.html',
            scope: true,
            link: function (scope, element, attrs) {

                var extName = 'scenario_rallyMode'
                var pics_folder = '/art/symbols/'

                scope.show_vnotes=true
                scope.opts=false
                scope.pics = []
                scope.picsflat = []

                scope.$on('pnotesHideSymbol', function (event, j) {
                    for (let i = 0; i < j; ++i) {
                        delete scope.pics[i]
                    }
                    scope.picsflat = [].concat.apply([], scope.pics);
                });

                scope.$on('pnotesQueueSymbol', function (event, data) {
                    let i = data.i
                    let pic = data.pics
                    // If the i-th element is not an array yet, create is
                    if (!(Array.isArray(scope.pics[i]))) {
                        scope.pics[i] = []
                    }
                    // Dump a pic needed for the i-th pacenote in the i-th
                    // element of the array
                    scope.pics[i].push(pic)
                    scope.picsflat = [].concat.apply([], scope.pics);
                });

                scope.saveOpts = function() {
                    // TODO: this is really lazy
                    let optString = scope.breathLength + ',' +
                        scope.timeOffset + ',' +
                        scope.visual + ',' +
                        scope.firstTime + ',' +
                        scope.volume + ',' +
                        scope.iconSize + ',' +
                        scope.iconPad
                    bngApi.engineLua(extName + '.uiToConfig("' + optString + '")')
                };

                scope.hideOpts = function() {
                    scope.opts = false
                };

                scope.dumpDebug = function() {
                    bngApi.engineLua(extName + '.dumpDebug()' )
                };

                scope.$on('cfgToUI', function (event, data) {
                    scope.hideMarkers = data.hideMarkers
                    scope.timeOffset = data.timeOffset
                    scope.posOffset = data.posOffset
                    scope.cutoff = data.cutoff
                    scope.linkWords = data.linkWords
                    scope.breathLength = data.breathLength
                    scope.recce = data.recce
                    scope.slowCorners = data.slowCorners
                    scope.visual = data.visual
                    scope.firstTime = data.firstTime
                    scope.codriverDir = data.codriverDir
                    scope.volume = data.volume
                    scope.iconSize = data.iconSize
                    scope.iconPad = data.iconPad
                });

                scope.$on('infoToUI', function (event, data) {
                    scope.info = data
                });


                scope.$on('saveUiOpts', function (event, data) {
                    scope.saveOpts()
                });

                scope.$on('showOpts', function (event, data) {
                    scope.opts = true
                });

                scope.$on('hideUiOpts', function (event, data) {
                    scope.hideOpts()
                });

            }
        }
    }])
