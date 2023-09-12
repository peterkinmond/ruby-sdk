module Extism
  # Represents a reference to a plugin in a host function
  # Use this class to read and write to the memory of the plugin
  # These methods allow you to get data in and out of the plugin
  # in a host function
  class CurrentPlugin
    # let's not let people construct these since it comes from a pointer
    private_class_method :new

    # Initialize a CurrentPlugin given an pointer
    #
    # @param ptr [FFI::Pointer] the raw pointer to the plugin
    def initialize(ptr)
      @ptr = ptr
    end

    # Allocates a memory block in the plugin
    #
    # @param amount [Integer] The amount in bytes to allocate
    # @return [Extism::Memory] The reference to the freshly allocated memory
    def alloc(amount)
      offset = LibExtism.extism_current_plugin_memory_alloc(@ptr, amount)
      Memory.new(offset, amount)
    end

    # Frees the memory block
    #
    # @param memory [Extism::Memory] The memory object you wish to free
    # @return [Extism::Memory] The reference to the freshly allocated memory
    def free(memory)
      LibExtism.extism_current_plugin_memory_free(@ptr, memory.offset)
    end

    # Gets the memory block at a given offset
    #
    # @raise [Extism::Error] if memory block could not be found
    #
    # @param offset [Integer] The offset pointer to the memory. This is relative to the plugin not the host.
    # @return [Extism::Memory] The reference to the memory block if found
    def memory_at_offset(offset)
      len = LibExtism.extism_current_plugin_memory_length(@ptr, offset)
      raise Extism::Error, "Could not find memory block at offset #{offset}" if len.zero?

      Memory.new(offset, len)
    end

    # Gets the input as a string
    #
    # @raise [Extism::Error] if memory block could not be found
    #
    # @param input [Extism::Val] The input val from the host function
    # @return [String] raw bytes as a string
    def input_as_string(input)
      raise ArgumentError, 'input is not an Extism::Val' unless input.instance_of? Extism::Val

      mem = memory_at_offset(input.value)
      memory_ptr(mem).read_bytes(mem.len)
    end

    # Sets string to the return of the host function
    #
    # @raise [Extism::Error] if memory block could not be found
    #
    # @param output [Extism::Val] The output val from the host function
    # @param bytes [String] The bytes to set
    def return_string(output, bytes)
      mem = alloc(bytes.length)
      memory_ptr(mem).put_bytes(0, bytes)
      set_return(output, mem.offset)
    end

    # Sets the return value parameter
    #
    # @raise [Extism::Error] if memory block could not be found
    #
    # @param output [Extism::Val] The output val from the host function
    # @param value [Integer | Float] The i32 value
    def set_return(output, value)
      case output.type
      when :i32, :i64, :f32, :f64
        output.value = value
      else
        raise ArgumentError, "Don't know how to set output type #{output.type}"
      end
    end

    private

    # Returns a raw pointer (absolute to the host) to the given memory block
    # Be careful with this. it's not exposed for a reason.
    # This is a pointer in host memory so it could read outside of the plugin
    # if manipulated
    def memory_ptr(mem)
      plugin_ptr = LibExtism.extism_current_plugin_memory(@ptr)
      FFI::Pointer.new(plugin_ptr.address + mem.offset)
    end
  end
end