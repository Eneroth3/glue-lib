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
  # @note Due to the workaround/hack used, this method can crash SketchUp if
  #   the components are not in the active drawing context.
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

      corners = CORNERS.map { |pt| pt.transform(instance.transformation) }

      # REVIEW: If this face merges with other geometry, everything breaks :( .
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
    temp_definition = component.definition

    mimic(component, target)
    target.erase!
    erase_definition(temp_definition)
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

  # Private

  # Corners for an arbitrary face around origin.
  CORNERS = [
    Geom::Point3d.new(-1, 0, 0),
    Geom::Point3d.new(0, -1, 0),
    Geom::Point3d.new(1, 0, 0),
    Geom::Point3d.new(0, 1, 0)
  ].freeze
  private_constant :CORNERS

  # Copy attributes from one entity to another.
  #
  # @param target [Sketchup::Entity]
  # @param reference [Sketchup::Entity]
  def self.copy_attributes(target, reference)
    # Entity#attribute_dictionaries returns nil instead of empty array, GAH!
    (reference.attribute_dictionaries || []).each do |attr_dict|
      attr_dict.each_pair { |k, v| target.set_attribute(attr_dict.name, k, v) }
      copy_attributes(target.attribute_dictionaries[attr_dict.name], attr_dict)
    end
  end

  # Erase a single definition.
  #
  # @param definition [Sketchup::ComponentDefiniton]
  def self.erase_definition(definition)
    if Sketchup.version.to_i >= 20
      # If I remember correctly the official API for removing a definition
      # originally caused bugsplats. Only use it in SketchUp 2020+ where the old
      # workaround may not work as SketchUp now can have empty groups and
      # components.
      definition.model.definitions.remove(definition)
    else
      definition.entities.clear
    end
  end
  private_class_method :erase_definition


  # Copy component properties over from reference to a target, making target
  # mimic the reference.
  #
  # @param target [Sketchup::ComponentInstance]
  # @param reference [Sketchup::ComponentInstance]
  def self.mimic(target, reference)
    target.definition = reference.definition
    target.layer = reference.layer
    target.material = reference.material
    target.transformation = reference.transformation
    copy_attributes(target, reference)
  end
  private_class_method :mimic
end
