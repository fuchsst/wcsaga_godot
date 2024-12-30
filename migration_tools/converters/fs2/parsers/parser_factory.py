"""Factory for creating FS2 file section parsers"""
from typing import Dict, Type, Optional
from .base_parser import BaseParser

class ParserFactory:
    """Factory for creating parser instances
    
    This is a singleton class that manages parser registration and creation.
    It ensures consistent parser instantiation across the codebase.
    
    Example:
        >>> factory = ParserFactory()
        >>> sexp_parser = factory.create_parser('sexp')
        >>> mission_parser = factory.create_parser('mission')
    """
    
    # Singleton instance
    _instance: Optional['ParserFactory'] = None
    
    # Parser registry
    _parsers: Dict[str, Type[BaseParser]] = {}
    
    # Parser instances cache
    _parser_instances: Dict[str, BaseParser] = {}
    
    def __new__(cls) -> 'ParserFactory':
        """Create or return the singleton instance
        
        Returns:
            ParserFactory: The singleton factory instance
        """
        if cls._instance is None:
            cls._instance = super(ParserFactory, cls).__new__(cls)
            cls._instance._parser_instances = {}
        return cls._instance
    
    def __init__(self):
        """Initialize the factory (only runs once due to singleton)"""
        # Nothing to initialize since we handle it in __new__
        pass
    
    @classmethod
    def create_parser(cls, parser_type: str) -> BaseParser:
        """Create or retrieve a parser instance
        
        Args:
            parser_type: Type of parser to create
            
        Returns:
            BaseParser: Parser instance
            
        Raises:
            ValueError: If parser_type is not recognized
        """
        # Get singleton instance
        instance = cls()
        
        # Validate parser type
        if parser_type not in cls._parsers:
            raise ValueError(
                f"Unknown parser type: {parser_type}. "
                f"Available parsers: {', '.join(cls._parsers.keys())}"
            )
        
        # Return cached instance if exists
        if parser_type in instance._parser_instances:
            return instance._parser_instances[parser_type]
        
        # Create new instance
        parser = cls._parsers[parser_type]()
        instance._parser_instances[parser_type] = parser
        return parser
    
    @classmethod
    def register_parser(cls, name: str, parser_class: Type[BaseParser]) -> None:
        """Register a new parser type
        
        Args:
            name: Name to register parser under
            parser_class: Parser class to register
            
        Raises:
            ValueError: If parser name is already registered
        """
        if name in cls._parsers:
            raise ValueError(f"Parser '{name}' is already registered")
            
        # Validate parser class implements BaseParser
        if not issubclass(parser_class, BaseParser):
            raise ValueError(
                f"Parser class must implement BaseParser interface: {parser_class}"
            )
            
        cls._parsers[name] = parser_class
        
        # Clear instance cache when registering new parser
        if cls._instance is not None:
            cls._instance._parser_instances = {}
    
    @classmethod
    def unregister_parser(cls, name: str) -> None:
        """Unregister a parser type
        
        Args:
            name: Name of parser to unregister
            
        Raises:
            ValueError: If parser is not registered
        """
        if name not in cls._parsers:
            raise ValueError(f"Parser '{name}' is not registered")
            
        del cls._parsers[name]
        
        # Clear instance cache when unregistering parser
        if cls._instance is not None:
            cls._instance._parser_instances = {}
    
    @classmethod
    def get_registered_parsers(cls) -> Dict[str, Type[BaseParser]]:
        """Get dictionary of registered parsers
        
        Returns:
            dict: Dictionary mapping parser names to parser classes
        """
        return cls._parsers.copy()
    
    @classmethod
    def has_parser(cls, name: str) -> bool:
        """Check if a parser type is registered
        
        Args:
            name: Parser name to check
            
        Returns:
            bool: True if parser is registered
        """
        return name in cls._parsers
    
    def clear_cache(self) -> None:
        """Clear the parser instance cache
        
        This can be useful when you want to force creation of new parser instances.
        """
        self._parser_instances.clear()
