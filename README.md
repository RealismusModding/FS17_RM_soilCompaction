[![Build Status](https://travis-ci.org/RealismusModding/FS17_RM_soilCompaction.svg?branch=master)](https://travis-ci.org/RealismusModding/FS17_RM_soilCompaction)

# FS17_RM_soilCompaction

This mod simulates soil compaction. Vehicles will compact the soil to varying degree depending on ground pressure, soil wetness etc. The soil can be decompacted with ploughing, rippers, cultivators etc.

WARNING: You are looking at the DEVELOPMENT VERSION of the Soil Compaction mod. This can break your game!

## Soil compaction
There are four levels of compaction (no, light, medium and heavy). The amount of soil compaction on the map can be monitored in the ingame menu "Map overview" showing "Soil composition". Higher degree of compaction will show by the deeper red colour when "Needs ploughing" is activated. This mod disables the vanilla mechanics of having to plough after every third harvest. Crop yield is reduced for increasing levels of compaction.

The amount of compaction acting by a certain equipment can be monitored in the F1 menu when standing outside and nearby the equipment.

The soil will compact easier if the soil is wet so keep in mind that conditions might change.

## Decompacting the soil
There are three different types of equipment that may be used to decompact the soil:
- Ploughs, rippers and subsoilers (decompacts 3 levels)
- Tine cultivators (decompacts 1 or 2 levels depending on setting)
- Disc cultivators (decompacts 1 level)

Ploughs, rippers and subsoilers decompact from all levels of compaction to no compaction. Note however, that if driving into the furrow when ploughing with a moldboard plough you will compact the soil in the furrow. 

Cultivators decompact the soil depending on the type. Cultivators with discs decompact one level of soil compaction. Cultivators with tines can either decompact one or two levels of compaction, depending on setting. The cultivation depth of these cultivators can be changed when the cultivator is attached and active. If shallow cultivation depth is selected, the cultivator offers less resistance and will be easier to pull.

Mod equipment can be set to be deep acting cultivators or subsoilers by adding one of the following in the vehicle.xml file:

    <scCultivation deep="true" />
    <scCultivation subsoiler="true" />

Multiple passes with a cultivator will not have an increased effect. Only the first pass is accounted for when the decompacting the soil.

Cultivating fully grown oilseed radish will decompact the soil one addition level.

## Tire pressure
The ground pressure is determined by the load each wheel transmits to the ground and the contact area. The contact area is generally determined by the radius and width of the wheel and the tire pressure. Lower tire pressure increases the contact area and decreases the ground pressure and soil compaction.

It is possible to change the tire pressure on all Motorized equipment that has wheels, as well as trailers, hook lift trailers, livestock trailers, liquid manure spreaders and fuel trailers. The default tire pressure is 1.8 bar (180 kPa) and it is possible to reduce it down to 0.8 bar (80 kPa) by using an air compressor. The air compressor, Wopstr A700, can be bought under category "Placeables" and is moveable. Start the air compressor and inflate or deflate the wheels. For simplicity, all wheels are set to same the tire pressure.

An in-cab tire pressure control system is available for mod tractors by adding the following to the vehicle.xml file:

    <scInCabTirePressureControl>true</scInCabTirePressureControl>

## Publishing
Only the Realismus Modding team is allowed to publish any of this code as a mod to any mod site, or file sharing site. The code is open for your own use, but give credit where due. Thus, when building your own version of Soil Compaction, give a credit notice to Realismus Modding when publishing screenshots or images. This is not required when using the only official published mod by Realismis Modding, on Giants ModHub. It would be a nice gesture however.

Making videos of development version
We have a couple of rules regarding videos to keep both our and our players experience the best. You are allowed to make videos with Soil Compaction, under a couple of simple conditions:

Do not share the GitHub link, if you are using a development version of the mod.

Do not explain how to install this mod. (The mod might also change at any moment, making your video outdated)

Give credit to 'Realismus Modding' as creators of the mod.

Link to our YouTube channel.

You do not need to put the mod name in the video title, but you can if you want.

Join us on Slack and tell us all about your awesome video.

Videos that are not holding to the rules will get a request for removal. If you have any questions about this policy you can ask them on Slack.

## Forking the code
You are allowed to fork this repository, apply changes and use those for private use. You are not allowed to distribute these changes yourself. Please open a pull request to allow for merging back your adjustments. (See also 'Publishing')

## Pull Requests
Please join us on Slack to discuss any changes you wish to make via pull requests, otherwise they are likely to be rejected, except for translations.