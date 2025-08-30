// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Collaborative Fiction Universe Protocol
 * @dev A decentralized platform for collaborative storytelling and universe building
 * @author CFUP Team
 */
contract CollaborativeFictionUniverse {
    
    // Structs
    struct Universe {
        uint256 id;
        string name;
        string description;
        address creator;
        bool isPublic;
        uint256 createdAt;
        uint256 storyCount;
        mapping(address => bool) authorizedAuthors;
    }
    
    struct Story {
        uint256 id;
        uint256 universeId;
        string title;
        string content;
        address author;
        uint256 createdAt;
        uint256 likes;
        bool isCanonical; // Whether this story is part of official universe canon
        mapping(address => bool) hasLiked;
    }
    
    struct Author {
        address authorAddress;
        string pseudonym;
        uint256 universeCount;
        uint256 storyCount;
        uint256 totalLikes;
        bool isRegistered;
    }
    
    // State variables
    mapping(uint256 => Universe) public universes;
    mapping(uint256 => Story) public stories;
    mapping(address => Author) public authors;
    mapping(uint256 => uint256[]) public universeStories; // universeId => storyIds[]
    
    uint256 public nextUniverseId = 1;
    uint256 public nextStoryId = 1;
    uint256 public totalUniverses;
    uint256 public totalStories;
    
    // Events
    event UniverseCreated(uint256 indexed universeId, string name, address indexed creator);
    event StoryAdded(uint256 indexed storyId, uint256 indexed universeId, string title, address indexed author);
    event AuthorRegistered(address indexed author, string pseudonym);
    event StoryLiked(uint256 indexed storyId, address indexed liker);
    event AuthorAuthorized(uint256 indexed universeId, address indexed author);
    event StoryMarkedCanonical(uint256 indexed storyId, uint256 indexed universeId);
    
    // Modifiers
    modifier onlyRegisteredAuthor() {
        require(authors[msg.sender].isRegistered, "Author must be registered");
        _;
    }
    
    modifier onlyUniverseCreator(uint256 _universeId) {
        require(universes[_universeId].creator == msg.sender, "Only universe creator can perform this action");
        _;
    }
    
    modifier universeExists(uint256 _universeId) {
        require(_universeId > 0 && _universeId < nextUniverseId, "Universe does not exist");
        _;
    }
    
    modifier storyExists(uint256 _storyId) {
        require(_storyId > 0 && _storyId < nextStoryId, "Story does not exist");
        _;
    }
    
    /**
     * @dev Register as an author in the platform
     * @param _pseudonym The author's chosen pseudonym
     */
    function registerAuthor(string memory _pseudonym) external {
        require(!authors[msg.sender].isRegistered, "Author already registered");
        require(bytes(_pseudonym).length > 0, "Pseudonym cannot be empty");
        
        authors[msg.sender] = Author({
            authorAddress: msg.sender,
            pseudonym: _pseudonym,
            universeCount: 0,
            storyCount: 0,
            totalLikes: 0,
            isRegistered: true
        });
        
        emit AuthorRegistered(msg.sender, _pseudonym);
    }
    
    /**
     * @dev Create a new fictional universe
     * @param _name Name of the universe
     * @param _description Description of the universe
     * @param _isPublic Whether the universe is open for public contribution
     */
    function createUniverse(
        string memory _name,
        string memory _description,
        bool _isPublic
    ) external onlyRegisteredAuthor returns (uint256) {
        require(bytes(_name).length > 0, "Universe name cannot be empty");
        
        uint256 universeId = nextUniverseId++;
        
        Universe storage newUniverse = universes[universeId];
        newUniverse.id = universeId;
        newUniverse.name = _name;
        newUniverse.description = _description;
        newUniverse.creator = msg.sender;
        newUniverse.isPublic = _isPublic;
        newUniverse.createdAt = block.timestamp;
        newUniverse.storyCount = 0;
        
        // Creator is automatically authorized
        newUniverse.authorizedAuthors[msg.sender] = true;
        
        authors[msg.sender].universeCount++;
        totalUniverses++;
        
        emit UniverseCreated(universeId, _name, msg.sender);
        return universeId;
    }
    
    /**
     * @dev Add a story to a universe
     * @param _universeId The universe to add the story to
     * @param _title Title of the story
     * @param _content Content of the story
     */
    function addStory(
        uint256 _universeId,
        string memory _title,
        string memory _content
    ) external onlyRegisteredAuthor universeExists(_universeId) returns (uint256) {
        require(bytes(_title).length > 0, "Story title cannot be empty");
        require(bytes(_content).length > 0, "Story content cannot be empty");
        
        Universe storage universe = universes[_universeId];
        
        // Check if author is authorized to write in this universe
        if (!universe.isPublic) {
            require(universe.authorizedAuthors[msg.sender], "Author not authorized for this universe");
        }
        
        uint256 storyId = nextStoryId++;
        
        Story storage newStory = stories[storyId];
        newStory.id = storyId;
        newStory.universeId = _universeId;
        newStory.title = _title;
        newStory.content = _content;
        newStory.author = msg.sender;
        newStory.createdAt = block.timestamp;
        newStory.likes = 0;
        newStory.isCanonical = false;
        
        // Add story to universe's story list
        universeStories[_universeId].push(storyId);
        universe.storyCount++;
        
        authors[msg.sender].storyCount++;
        totalStories++;
        
        emit StoryAdded(storyId, _universeId, _title, msg.sender);
        return storyId;
    }
    
    /**
     * @dev Like a story
     * @param _storyId The story to like
     */
    function likeStory(uint256 _storyId) external storyExists(_storyId) {
        Story storage story = stories[_storyId];
        require(!story.hasLiked[msg.sender], "Already liked this story");
        
        story.hasLiked[msg.sender] = true;
        story.likes++;
        authors[story.author].totalLikes++;
        
        emit StoryLiked(_storyId, msg.sender);
    }
    
    // Additional utility functions
    
    /**
     * @dev Authorize an author to write in a private universe
     * @param _universeId The universe to grant access to
     * @param _author The author to authorize
     */
    function authorizeAuthor(uint256 _universeId, address _author) 
        external 
        onlyUniverseCreator(_universeId) 
        universeExists(_universeId) 
    {
        require(authors[_author].isRegistered, "Author must be registered");
        universes[_universeId].authorizedAuthors[_author] = true;
        emit AuthorAuthorized(_universeId, _author);
    }
    
    /**
     * @dev Mark a story as canonical (official universe lore)
     * @param _storyId The story to mark as canonical
     */
    function markStoryCanonical(uint256 _storyId) 
        external 
        storyExists(_storyId) 
    {
        Story storage story = stories[_storyId];
        require(
            universes[story.universeId].creator == msg.sender, 
            "Only universe creator can mark stories as canonical"
        );
        
        story.isCanonical = true;
        emit StoryMarkedCanonical(_storyId, story.universeId);
    }
    
    // View functions
    
    /**
     * @dev Get universe details
     * @param _universeId The universe ID
     */
    function getUniverse(uint256 _universeId) 
        external 
        view 
        universeExists(_universeId) 
        returns (
            string memory name,
            string memory description,
            address creator,
            bool isPublic,
            uint256 createdAt,
            uint256 storyCount
        ) 
    {
        Universe storage universe = universes[_universeId];
        return (
            universe.name,
            universe.description,
            universe.creator,
            universe.isPublic,
            universe.createdAt,
            universe.storyCount
        );
    }
    
    /**
     * @dev Get story details
     * @param _storyId The story ID
     */
    function getStory(uint256 _storyId) 
        external 
        view 
        storyExists(_storyId) 
        returns (
            string memory title,
            string memory content,
            address author,
            uint256 universeId,
            uint256 createdAt,
            uint256 likes,
            bool isCanonical
        ) 
    {
        Story storage story = stories[_storyId];
        return (
            story.title,
            story.content,
            story.author,
            story.universeId,
            story.createdAt,
            story.likes,
            story.isCanonical
        );
    }
    
    /**
     * @dev Get all story IDs in a universe
     * @param _universeId The universe ID
     */
    function getUniverseStories(uint256 _universeId) 
        external 
        view 
        universeExists(_universeId) 
        returns (uint256[] memory) 
    {
        return universeStories[_universeId];
    }
    
    /**
     * @dev Check if an author is authorized for a universe
     * @param _universeId The universe ID
     * @param _author The author address
     */
    function isAuthorizedForUniverse(uint256 _universeId, address _author) 
        external 
        view 
        universeExists(_universeId) 
        returns (bool) 
    {
        return universes[_universeId].isPublic || universes[_universeId].authorizedAuthors[_author];
    }
    
    /**
     * @dev Get author statistics
     * @param _author The author address
     */
    function getAuthorStats(address _author) 
        external 
        view 
        returns (
            string memory pseudonym,
            uint256 universeCount,
            uint256 storyCount,
            uint256 totalLikes,
            bool isRegistered
        ) 
    {
        Author storage author = authors[_author];
        return (
            author.pseudonym,
            author.universeCount,
            author.storyCount,
            author.totalLikes,
            author.isRegistered
        );
    }
}
