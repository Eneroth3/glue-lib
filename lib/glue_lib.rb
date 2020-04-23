# frozen_string_literal: true

# Library for filling holes in the SketchUp Ruby API coverage regarding
# to gluing.
module GlueLib
  # Glue instance to other instance.
  #
  # Workaround for the SketchUp API ComponentInstance#glued_to= not supporting
  # other instances. Due to technical limitations, the persistent ID is lost for
  # the target.
  #
  # @param instances [Sketchup::ComponentInstance,
  #   Array<Sketchup::ComponentInstance>]
  # @param target [Sketchup::ComponentInstance]
  def self.glue(instances, target)
    # Wrap in array.
    instances = [*instances]

    instances += glued_to(target)

    faces = instances.map do |instance|
      instance.definition.behavior.is2d = true # "is2d" = "gluable"

      corners = [
        Geom::Point3d.new(-1, -1, 0),
        Geom::Point3d.new(1, -1, 0),
        Geom::Point3d.new(1, 1, 0),
        Geom::Point3d.new(-1, 1, 0)
      ].map { |pt| pt.transform(instance.transformation) }

      # If this face merges with other geometry, everything breaks :( .
      # It has to lie loosely in this drawing context though to be able to glue
      # to.
      face = instance.parent.entities.add_face(corners)
      instance.glued_to = face

      face
    end

    # HACK: Make a group from existing geometry to allow the gluing to be
    # carried over from an entity the API allows gluing to, to one we want
    # gluing to.
    group = instances.first.parent.entities.add_group(faces)
    component = group.to_component

    component.definition = target.definition
    component.layer = target.layer
    component.material = target.material
    component.transformation = target.transformation
    target.erase!
    # TODO: Copy attributes.
    # TODO: Purge temp definition.
  end

  # Get all instances glued to an instance.
  #
  # @param instance [Sketchup::ComponentInstance]
  #
  # @return [Array<Sketchup::ComponentInstance>]
  def self.glued_to(instance)
    instance.parent.entities.grep(Sketchup::ComponentInstance)
            .select { |c| c.glued_to == instance }
  end
end
