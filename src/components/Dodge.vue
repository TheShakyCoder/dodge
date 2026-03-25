<script setup lang="ts">
import P5 from 'p5'
import {onMounted, reactive, ref} from "vue";

import nippleJs from 'nipplejs';
import type {JoystickManager} from 'nipplejs';

import type {iAsteroid} from "../interfaces/dodge/iAsteroid"
import type {iShip} from "../interfaces/dodge/iShip"
import type {iShipType} from "../interfaces/dodge/iShipType"

const touchScreen = ref(false)
let joystick: JoystickManager | null = null

const joystickMovement = reactive({
    x: 0,
    y: 0
})
let nippleAngle: number | null = null
let nippleForce: number = 0

onMounted(() => {
    if(window.matchMedia("(pointer: coarse)").matches)
        touchScreen.value = true

    joystick = nippleJs.create({
        zone: document.getElementById('zone_joystick') as HTMLElement,
        mode: 'semi',
        restJoystick: true
    });

    joystick.on('move', function(evt, data) {
        nippleAngle = data.angle.radian
        nippleForce = Math.min(1, data.force)
    })
        joystick.on('end', function (evt, data) {
        nippleAngle = null
        nippleForce = 0
    });
})

const arena = {
  width: 800,
  height: 800
}

const browser = {
  width: window.innerWidth,
  height: window.innerHeight
}

const asteroids = ref(<iAsteroid[]>[])
const asteroidCount = ref(0)
const maxAsteroids = 99
const frameRate = ref(33)
const delta = ref(0)

const shipMode = ref('dodge')
const shipTypes: iShipType[] = [
    {
        name: 'dodge',
        speed: 60,
        radius: 20,
        shieldRadius: 1,
        life: 2
    },
    {
        name: 'shield',
        speed: 50,
        radius: 25,
        shieldRadius: 50,
        life: 2
    }
]

const asteroidSpeed = 70
const asteroidRadius = 25

const weaponChargeTime = 5000
let weaponCharged = true

let positionMiddle: P5.Vector
let noVector: P5.Vector

let me: iShip

const playing = ref(false)

new P5(( sketch: P5 ) => {
  sketch.setup = () => {
    sketch.createCanvas(browser.width, browser.height);
    sketch.frameRate(frameRate.value)

      positionMiddle = sketch.createVector(arena.width / 2, arena.height / 2)
      noVector = sketch.createVector(0, 0)

    setInterval(createAsteroid, 1000, sketch)
  }
  sketch.draw = () => {
    delta.value = sketch.frameRate()
    sketch.background(100)
    sketch.push()
    sketch.translate(sketch.width / 2, sketch.height / 2)
    if(me)
      sketch.translate(-me.position.x, -me.position.y)
    else
      sketch.translate(-arena.width / 2, -arena.height / 2)

    drawArena(sketch)
    processAsteroids(sketch, asteroids.value)
    processMe(sketch, me)

    sketch.pop()
  }
})

function drawArena(sketch: P5) {
    sketch.fill(55)
    sketch.rect(0, 0, arena.width, arena.height)

    sketch.stroke(255)
    sketch.strokeWeight(4)
    for(let x = 100; x < arena.width; x = x + 100) {
        for(let y = 100; y < arena.height; y = y + 100) {
            sketch.point(x, y)
        }
    }
}

function processAsteroids(sketch: P5, asteroids: Array<iAsteroid>) {
  sketch.stroke(255)
  sketch.strokeWeight(1)
  asteroids.forEach((asteroid: iAsteroid, index: number) => {
      processAsteroid(sketch, asteroid, index)
  })
}

function processAsteroid(sketch: P5, asteroid: iAsteroid, index: number) {
  const newVector = sketch.createVector(asteroid.vector.x * sketch.deltaTime / 1000, asteroid.vector.y * sketch.deltaTime / 1000)
  asteroid.position.add(newVector)
  if(asteroid.position.x > (arena.width + asteroid.radius))
    asteroid.position.x = -asteroid.radius
  if(asteroid.position.x < -asteroid.radius)
    asteroid.position.x = arena.width + asteroid.radius
  if(asteroid.position.y > (arena.height + asteroid.radius))
    asteroid.position.y = -asteroid.radius
  if(asteroid.position.y < -asteroid.radius)
    asteroid.position.y = arena.height + asteroid.radius

  asteroid.distanceSquared = getDistance(asteroid)
  if(checkShield(asteroid) && weaponCharged)
    destroyAsteroid(index)
  if(checkCollision(asteroid))
    collided(asteroid)
  drawAsteroid(sketch, asteroid)
}

function collided(asteroid: iAsteroid) {
    end()
}

function drawAsteroid(sketch: P5, asteroid: iAsteroid) {
  sketch.fill(0)
  sketch.circle(asteroid.position.x, asteroid.position.y, asteroid.radius * 2)
  sketch.fill(255)
  sketch.textSize(18)
  sketch.textAlign(sketch.CENTER, sketch.CENTER);
  sketch.text(asteroid.name, asteroid.position.x, asteroid.position.y)
}

function processMe(sketch: P5, me: iShip) {
    if(!me)
        return

    if(weaponCharged)
        sketch.fill(0, 180, 0)
    else
        sketch.fill(255, 0, 0)
    sketch.noStroke()
    sketch.circle(me.position.x, me.position.y, me.radius * 2)
    //  weapon
    sketch.noFill()
    if(weaponCharged)
        sketch.stroke(0, 180, 0)
    else
        sketch.stroke(255, 0, 0)

    sketch.strokeWeight(1)
    sketch.circle(me.position.x, me.position.y, me.shieldRadius * 2)
    //  level text
    sketch.fill(255)
    sketch.textSize(20)
    sketch.textStyle(sketch.BOLD)
    sketch.textAlign(sketch.CENTER, sketch.CENTER);
    sketch.noStroke()
    sketch.text(asteroidCount.value.toString(), me.position.x, me.position.y)

    captureMovement(sketch)
}

function checkShield(asteroid: iAsteroid) {
    const zSquared = (asteroid.radius + me.shieldRadius) * (asteroid.radius + me.shieldRadius)
    return asteroid.distanceSquared < zSquared
}

function destroyAsteroid(asteroidIndex: number) {
    asteroids.value.splice(asteroidIndex, 1)
    weaponCharged = false
    setTimeout(function () {
        weaponCharged = true
    }, weaponChargeTime)
}

function start(mode: string) {
  shipMode.value = mode
  asteroidCount.value = 0
  asteroids.value = []
    weaponCharged = true

    me = reactive<iShip>({
        position: positionMiddle,
        vector: noVector,
        radius: shipTypes.filter(ship => ship.name === shipMode.value)[0].radius,
        shieldRadius: shipTypes.filter(ship => ship.name === shipMode.value)[0].shieldRadius,
        life: shipTypes.filter(ship => ship.name === shipMode.value)[0].life
    })
    me.position.x = 400
    me.position.y = 400

  playing.value = true
}

function end() {
  playing.value = false
}

function captureMovement(sketch: P5) {
  let movement = {...joystickMovement}
  let vector
  if (sketch.keyIsDown(65))
    movement.x = -1

  if (sketch.keyIsDown(68))
    movement.x = 1

  if (sketch.keyIsDown(87))
    movement.y = -1

  if (sketch.keyIsDown(83))
    movement.y = 1

  const shipType = shipTypes.filter(ship => ship.name === shipMode.value)[0]
  if(nippleAngle)
    vector = sketch.createVector(
      sketch.cos(nippleAngle) * nippleForce * sketch.deltaTime * shipType.speed / 1000,
      -sketch.sin(nippleAngle) * nippleForce * sketch.deltaTime * shipType.speed / 1000
    )
  else
    vector = sketch.createVector(
      movement.x * sketch.deltaTime * shipType.speed / 1000,
      movement.y * sketch.deltaTime * shipType.speed / 1000
    )

  if(playing.value)
    me.position.add(vector)

  me.position.x = sketch.min(me.position.x, arena.width)
  me.position.y = sketch.min(me.position.y, arena.height)
  me.position.x = sketch.max(me.position.x, 0)
  me.position.y = sketch.max(me.position.y, 0)
}

function createAsteroid(sketch: P5): void {
  if(!playing.value || asteroidCount.value > maxAsteroids)
    return

  asteroidCount.value++
  asteroids.value.push({
    name: asteroidCount.value.toString(),
    position: sketch.createVector(-asteroidRadius, -asteroidRadius),
    vector: sketch.createVector(sketch.random(-asteroidSpeed, asteroidSpeed), sketch.random(-asteroidSpeed, asteroidSpeed)),
    radius: asteroidRadius,
    distanceSquared: arena.width,
    life: 5
  })
}

function checkCollision(asteroid: iAsteroid): boolean {
    const zSquared = (asteroid.radius + me.radius) * (asteroid.radius + me.radius)
    return asteroid.distanceSquared < zSquared
}

function getDistance(asteroid: iAsteroid) {
    const xDiff = Math.abs(me.position.x - asteroid.position.x)
    const yDiff = Math.abs(me.position.y - asteroid.position.y)

    const xSquared = xDiff * xDiff
    const ySquared = yDiff * yDiff

    return  xSquared + ySquared
}
</script>

<template>
    <Head title="Dodge Game" />

  <div class="bottom-1 left-1 right-1 bg-red-500 bg-opacity-50 h-28 z-30" :class="[touchScreen ? 'absolute' : 'hidden']" id="zone_joystick"></div>
  <div class="absolute left-0 top-0 right-0 z-20">
    <ul class="bg-white bg-opacity-50 px-5 sm:px-8 py-4 sm:py-6">
      <li class="flex">
        <div class="w-32">Level</div>
        <div class="text-right font-bold w-16">{{ asteroidCount }}</div>
      </li>
      <li class="flex">
        <div class="w-32">Frame Rate</div>
        <div class="text-right font-bold w-16">{{ Math.round(delta) }}</div>
      </li>

    </ul>
  </div>

    <div class="absolute inset-0 flex flex-col justify-center items-center">
  <transition
    enter-active-class="duration-150 ease-out"
    enter-from-class="opacity-0 scale-95"
    enter-to-class="opacity-100 scale-100"
    leave-active-class="duration-150 ease-in"
    leave-from-class="opacity-100 scale-100"
    leave-to-class="opacity-0 scale-95"
  >
      <div  v-if="!playing" class="bg-white bg-opacity-80 rounded-xl w-60 text-black py-12 flex flex-col justify-center items-center z-30">
        <div v-if="asteroidCount === 0" class="text-center">
          <p v-if="touchScreen">Touch the red bar.</p>
          <p v-else>Use the WASD keys.</p>
          <p>Avoid the black balls.</p>
          <p>Survive to level {{ maxAsteroids }}.</p>
          <p>Muh ha ha ha!</p>
        </div>
        <div v-else>
          <div class="text-center ">You got to level</div>
          <div class="text-center text-7xl font-bold">{{ asteroidCount }}</div>
        </div>
        <div class="w-full flex justify-around my-4">
          <button @click="start('dodge')" class="w-20 p-2 px-3 rounded-2xl bg-green-600 text-white font-bold">Dodge</button>
          <button @click="start('shield')" class="w-20 p-2 px-3 rounded-2xl bg-green-600 text-white font-bold">Shield</button>
        </div>
        <a class="underline" href="/">Home</a>
        <a class="underline" href="https://bitbucket.org/FigLimited/sharifkhan/src/main/resources/js/Pages/Dodge.vue">Source Code</a>
      </div>
  </transition>
    </div>
</template>

<style scoped>

</style>
