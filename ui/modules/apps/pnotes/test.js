
var app = angular.module("myApp", []);

app.controller("myCtrl", function($scope) {
    let a = []
    $scope.sa = false
    $scope.timeOffset = 0.2
    $scope.posOffset = 0.2
    $scope.cutoff = 0.2
    $scope.linkWords = ["ass", "ass2"]
    $scope.slowCorners = ["ass", "ass2"]
    $scope.codriver = "ass ass ass"
    $scope.breathLength = 0.2
    $scope.recce = true
    $scope.hideMarkers = true
    $scope.visual = true
    lista = [ "./symbols/1 left.svg", "./symbols/into.svg", "./symbols/2 left.svg", "./symbols/100.svg" ]
    listb = [ "./symbols/1 right.svg", "./symbols/unseen.svg", "./symbols/300.svg", ]
    $scope.pics = [lista, listb]
    $scope.icon_size = 120
    $scope.min = 0
    $scope.max = 10
    $scope.volume = 10
});

