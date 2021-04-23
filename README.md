# RoadTrafficSimulator

Traffic simulator and road lights adjuster using
[Intelligent Driver Model](https://en.wikipedia.org/wiki/Intelligent_driver_model)
and lane-changing model MOBIL. Written in CoffeeScript and HTML5.

## Demo
https://davidguzmanr.github.io/files/RoadTrafficSimulator.html

- Mouse and wheel - scrolling and zoom
- shift + click -- create intersection
- shift + drag from one intersection to another -- create road

Or just press `generateMap` in control panel and add cars with `carsNumber` slider. To change the number of lanes
use the `lanesNumber` slider and then press `load`. You can create traffic in a certain direction by adding cars in the 
specific direction using the `addCar` options.

To run simulator

    git clone https://github.com/davidguzmanr/RoadTrafficSimulator.git
    cd RoadTrafficSimulator
    npm install

And open `index.html` in your browser. Use **gulp** to rebuild project. See [How to install NodeJS](https://www.digitalocean.com/community/tutorials/como-instalar-node-js-en-ubuntu-18-04-es)
and [How to install Gulp](https://tecadmin.net/install-gulp-js-on-ubuntu/) to install the necessary in Ubuntu.

# References
The original is in [volkhin](https://github.com/volkhin/RoadTrafficSimulator), I am just making changes to it 
for my needs.