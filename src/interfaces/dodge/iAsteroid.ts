import {iBody} from "./iBody";

export interface iAsteroid extends iBody {
    name: string,
    distanceSquared: number,
}
