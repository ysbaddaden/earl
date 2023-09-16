module Crystal::AtExitHandlers
  def self.__earl_prepend(&handler : Int32, Exception? ->) : Nil
    handlers.unshift(handler)
  end
end
