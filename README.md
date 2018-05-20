# FS17_RM_soilCompaction

This mod simulates soil compaction. Vehicles with high ground pressure will compact the soil. The soil can be decompacted with ploughing, rippers, cultivators etc.

## Soil compaction
There are four levels of compaction (no, light, medium and heavy). The amount of soil compaction on the map can be monitored in the ingame menu "Map overview" showing "Soil composition". Higher degree of compaction will show by the deeper red colour when "Needs ploughing" is activated. This mod disables the vanilla mechanics of having to plough after every third harvest.

The amount of compaction a certain equipment will give can be seen in the F1 menu when standing outside and nearby the equipment. Note that currently the display will only be shown after you have been driving the vehicle for a bit.

The soil will compact easier if the soil is wet.

## Decompacting the soil
Ploughs, rippers and subsoilers decompact from all levels of compaction to no compaction. Note however, that if driving into the furrow when ploughing with a moldboard plough you will compact the soil in the furrow. 

Cultivators decompact the soil depending on the type. Cultivators with discs decompact one level of soil compaction. Cultivators with tines can either decompact one or two levels of compaction, depending on setting. The cultivation depth of these cultivators can be changed when the cultivator is attached and active.

Mod equipment can be set to be deep acting cultivators or subsoilers by adding one of the following in the vehicle.xml file:

    <scCultivation>deep</scCultivation>
    <scCultivation>subsoiler</scCultivation>

Multiple passes with a cultivator will not have an increased effect. Only the first pass is accounted for the decompacting the soil.
