# RubyETI
# A Ruby interface to ETI
# Designed by Christopher Lenart
# Contact: clenart1@gmail.com
# Open Source. 
# https://github.com/clenart/rubyeti
# Linking to my github in your documentation would be greatly appreciated :)

# I assume no responsibility if you get banned for using this.

# Uses Ruby style exceptions
# All exceptions specific to this program are subclasses of ETIError
# All functions throw LoginError when the user is not logged into ETI
class RubyETI
    # logs a user into the site with their credentials
    # with the session ("desktop" or "iphone") they specify
    # returns true on success
    # throws SessionError if an invalid session is passed
    def login username, password, session = "iphone"
    end

    # posts a topic with the specified name and content
    # to all the tags listed in the array tag_list
    # sig is NOT automatically appended yet
    def post_topic topic_name, topic_content, tag_list = ["LUE"]
    end

    # retrieves a topic list object, which is the first page of topics matching the tag combo entered
    # tags should be passed as one string, as if you were putting it in the text box on the
    # + page on ETI
    # DOES NOT WORK WITH ANONYMOUS TOPICS
    # throws TopicError
    def get_topic_list tag_list = "LUE"
    end

    # retrieves a topic by id
    # returns a topic object on success
    # DOES NOT WORK WITH ANONYMOUS TOPICS
    # throws TopicError
    def get_topic_by_id id
    end

    # returns an array of topic objects, based on the topic ids passed in the ids array
    # throws TopicError
    def get_topics_by_id ids
    end

    # returns an array of topic objects, based on the range of topics between first_id
    # and last_id, inclusive
    # throws TopicError
    def get_topic_range first_id, last_id
    end

    # stars the topic id
    # throws TopicError
    def star_topic_by_id id
    end

    # unstars the topic id
    # throws TopicError
    def unstar_topic_by_id id
    end

    # returns the userid of the specified username
    # returns false and error message if not found
    # throws UserError
    def get_user_id username
    end

    ###############################################################################
    # these four functions send tokens by either integer userid or string username
    # to send anonymously, set the anon argument to true
    # throws ETIError on failure

    def send_good_token_by_id       userid,   reason, anon = false
    end

    def send_good_token_by_username username, reason, anon = false
    end

    def send_bad_token_by_id        userid,   reason, anon = false
    end

    def send_bad_token_by_username  username, reason, anon = false
    end

    ###############################################################################

    # uploads an image to eti and returns the <img> code as a string
    # only has been tested with absolute paths from the root directory
    def upload_image path_to_image
    end

    # returns true if online
    # false if not
    # throws UserError
    def is_user_online username
    end

    # returns true if online
    # false if not
    # throws UserError
    def is_user_online_by_id userid
    end

    # creates a new private message thread with the user specified by the userid user
    # does NOT send your sig automatically
    # both subject AND message must be >= 5 characters, or will fail
    # does not work with *special* characters
    # throws UserError
    def create_private_message username, subject, message
    end

    def create_private_message_by_id userid, subject, message
    end
end

class ETIError < StandardError
end

class LoginError < ETIError
end

class SessionError < ETIError
end

class TopicError < ETIError
end

class UserError < ETIError
end

class RubyETI

    def initialize
        @connection = RubyETI_connector.new
    end

    def login username, password, session="iphone"
        username = username.chomp
        password = password.chomp
        # connects the eti connector using the login info
        @connection.connect username, password, session
        # tests the connection
        @connection.test_connection
    end

    def post_topic topic_name, topic_content, tag_list = ["LUE"]
        tag_field = ""
        for tag in tag_list
            if(tag!=tag_list[0])
                tag_field += ","
            end
            tag_field += tag
        end
        # gets the html from the post msg page, to get the hash value
        html_source     = @connection.get_html "http://boards.endoftheinter.net/postmsg.php?tag=" + tag_field
        # creates nokogiri object to parse
        html_doc        = Nokogiri::HTML(html_source)
        # finds the hash tag
        hash_field      = html_doc.xpath('//input[@name = "h"]')
        # extracts the hash from the html tag
        hash            = hash_field[0]["value"]
        # posts the topic using POST
        post_response = @connection.post_html "http://boards.endoftheinter.net/postmsg.php", "title=" + topic_name + "&tag=" + tag_field + "&message=" + topic_content + "&h=" + hash + "&submit=Post Message"
        if post_response.code != 302
            raise TopicError, "Failed to POST topic.\nCode = " + post_response.code.to_s
        end
        # retrieves topic id
        response_headers = post_response.headers
        next_header = false
        topic_id = ""
        for header in response_headers
            for element in header
                if next_header
                    topic_id = element.to_s.partition("=")[2]
                    break
                end
                if element == "Location"
                    next_header = true
                else
                    next_header = false
                end
            end
            if next_header
                break
            end
        end

        return topic_id.to_i

    end

    def get_topic_list tag_list = "LUE"
        url         = "http://boards.endoftheinter.net/topics/" + tag_list

        html_source = @connection.get_html url

        html_doc    = Nokogiri::HTML(html_source)
        # gets the <a> html tags that contain links to the topics on the topic list
        topics      =  html_doc.xpath('//td[@class = "oh"]/div[@class = "fl"]//a')
        # gets the number of msgs
        posts       =  html_doc.xpath('//table[@class = "grid"]/tr/td')
        # gets the tag divs
        tags        =  html_doc.xpath('//td[@class = "oh"]/div[@class = "fr"]')
        topic_list_return = TopicList.new

        i = 0
        
        for topic in topics
            t = TopicListRow.new
            # extracts the topic name from the <a> html tags
            t.topic_name = topic.text
            # extracts the topic id from the <a> html tags
            topic_id = topic["href"]
            t.topic_id = topic_id.partition("=")[2]
            # extracts the tags from the <div class="fr"> tags
            tag_array = []
            tag_names = tags[i].text

            while tag_names != ""
                tag_array << tag_names.partition(" ")[0]
                tag_names = tag_names.partition(" ")[2]
            end

            t.tags = tag_array
            # extracts the tc from the table
            t.tc = posts[1+i*4].text.to_s
            # extracts the number of pages from the table
            t.msgs = posts[2+i*4].text.to_i
            # extracts the last post time from the table
            t.last_post = posts[3+i*4].text.to_s
            topic_list_return.topics << t
            i += 1
        end

        return topic_list_return
    end

    def get_topic_by_id id
        t = Topic.new
        begin
            html_source = @connection.get_html "http://boards.endoftheinter.net/showmessages.php?topic=" + id.to_s
        rescue ETIError
            html_source = @connection.get_html "http://archives.endoftheinter.net/showmessages.php?topic=" + id.to_s
            t.archived = true
        else
            t.archived = false
        end
        
        t = parse_topic_html(html_source, t, 1)

        html_doc = Nokogiri::HTML(html_source)

        tags = html_doc.xpath('//h2/div/a')
        tag_array = []
        for tag in tags
            tag_array << tag.text
        end
        t.tags = tag_array
        # retrieve a list of links to the next pages of the topic
        next_page_links = html_doc.xpath('//div[@id = "u0_2"]/span')
        number_of_pages = next_page_links[0].text.to_i
        # if no links exist, return
        if number_of_pages == 1
            return t
        else
            if t.archived
                suburl = "archives"
            else
                suburl = "boards"
            end
            requests = []
            for i in 2..number_of_pages
                requests << @connection.queue("http://" + suburl + ".endoftheinter.net/showmessages.php?topic=" + t.topic_id.to_s + "&page=" + i.to_s)
            end
            @connection.run
            for i in 2..number_of_pages
                t = parse_topic_html(requests[i-2].response.body, t, i)
            end
        end
        return t
    end

    def get_topics_by_id ids
        topics = []
        for id in ids
            topics << (get_topic_by_id id)
        end
        return topics
    end

    def get_topic_range first_id, last_id
        topics = []
        i = first_id
        while i <= last_id do
            topics << (get_topic_by_id i)
            i += 1
        end
        return topics
    end

    def star_topic_by_id id
        response = @connection.post_html "http://boards.endoftheinter.net/ajax.php?r=1&t=" + id.to_s
        if response.code != 200
            raise TopicError, "Failed to star topic " + id.to_s
        end
        return true
    end

    def unstar_topic_by_id id
        response = @connection.post_html "http://boards.endoftheinter.net/ajax.php?r=2&t=" + id.to_s
        if response.code != 200
            raise TopicError, "Failed to unstar topic " + id.to_s
        end
        return true
    end

    def get_user_id username
        user_search_source = @connection.get_html "http://endoftheinter.net/async-user-query.php?q=" + username
        user_search_source = user_search_source.partition(",\"")[2]
        user_search_source = user_search_source.partition("\"")[0]
        if(user_search_source.size==0)
            raise UserError, "User does not exist"
        else
            return user_search_source.to_i
        end
    end

    def send_good_token_by_id userid, reason, anon = false
        if anon
            response = @connection.post_html "http://endoftheinter.net/token.php", "type=2&user=" + userid.to_s + "&anon=off&reason=" + reason
        else
            response = @connection.post_html "http://endoftheinter.net/token.php", "type=2&user=" + userid.to_s + "&reason=" + reason
        end
        if response.code != 302
            raise ETIError, "Could not send good token to userid " + userid.to_s + "\nCode: " + response.code.to_s
        end
        true
    end

    def send_good_token_by_username username, reason, anon = false
        userid = get_user_id username
        return send_good_token_by_id userid, reason, anon
    end

    def send_bad_token_by_id userid, reason, anon = false
        if anon
            response = @connection.post_html "http://endoftheinter.net/token.php", "type=1&user=" + userid.to_s + "&anon=off&reason=" + reason
        else
            response = @connection.post_html "http://endoftheinter.net/token.php", "type=1&user=" + userid.to_s + "&reason=" + reason
        end
        if response.code != 302
            raise ETIError, "Could not send good token to userid " + userid.to_s + "\nCode: " + response.code.to_s
        end
        true
    end

    def send_bad_token_by_username username, reason, anon = false
        userid = get_user_id username
        return send_bad_token_by_id userid, reason, anon
    end

    def upload_image path_to_image
        response = @connection.upload_image path_to_image
        if response.code != 200
            raise ETIError, "Image uploading failed, HTTP code = " + response.code.to_s
        end
        html = response.body
        html_doc = Nokogiri::HTML(html)
        image_link = html_doc.xpath('//div[@class = "img"]/input')
        if image_link[0] == nil
            raise ETIError, "Image uploading failed, invalid file format"
        end
        im_link = image_link[0]["value"]
        im_link = extract_escape_characters im_link
    end

    def is_user_online username
        user_id = get_user_id username

        html_source = @connection.get_html "http://endoftheinter.net/profile.php?user=" + user_id.to_s
        html_parse = Nokogiri::HTML(html_source)
        online_now = html_parse.xpath('//td[contains(text(), "online now")]');
        if online_now.size == 0
            return false
        else
            return true
        end
    end

    def is_user_online_by_id userid
        html_source = @connection.get_html "http://endoftheinter.net/profile.php?user=" + userid.to_s
        html_parse = Nokogiri::HTML(html_source)
        online_now = html_parse.xpath('//td[contains(text(), "online now")]');
        if online_now.size == 0
            return false
        else
            return true
        end
    end

    def create_private_message username, subject, message
        userid = get_user_id(username)
        create_private_message_by_id(userid, subject, message)
    end

    def create_private_message_by_id userid, subject, message
        

        # this block is to get the "h" value from the post message page
        # this seems to be unique to each user, not sure exactly how
        # so for now im just loading up the new PM thread page and grabbing it
        # from the html source
        html_source     = @connection.get_html "http://endoftheinter.net/postmsg.php?puser=" + userid.to_s
        html_doc        = Nokogiri::HTML(html_source)
        hash_field      = html_doc.xpath('//input[@name = "h"]')
        hash            = hash_field[0]["value"]

        # posts the pm information to the connection
        # DOES NOT send your sig automatically
        @connection.url = "http://endoftheinter.net/postmsg.php"
        post_field      = "puser=" + userid.to_s + "&title=" + subject.to_s + "&message=" + message.to_s + "&h=" + hash.to_s + "&submit=Send Message"
        @connection.post_html post_field
    end

private

    def parse_topic_html html_source, topic, page
        # creates a new topic to store the data in
        t = topic

        # creates a nokogiri object for parsing the topic
        html_doc            = Nokogiri::HTML(html_source)
        em = html_doc.xpath('//div/em')
        if em[0] != nil && em.text == "Invalid topic."
            raise TopicError, 'Invalid topic'
        end

        # gets the topic id
        suggest_tag_link    = html_doc.xpath('//a[contains(@href, "edittags.php")]')
        link                = suggest_tag_link[0]["href"]
        link                = link.partition("=")[2]
        t.topic_id          = link.to_i

        # gets the topic title
        t.topic_title       = html_doc.xpath('//h1').text

        # sets the archived flag
        h2 = html_doc.xpath('//h2')
        if(h2.size > 1)
            t.archived = true
        else
            t.archived = false
        end

        # gets a list of the timestamps. these are still embedded in other text, the for loop
        # takes care of extracting them
        timestamps          = html_doc.xpath('//div[@class = "message-container"]')

        # gets a list of the posters
        posters             = html_doc.xpath('//div[@class = "message-container"]/div[@class = "message-top"]/a[contains(@href, "profile.php")]')

        # gets a list of the link nodes with message_id
        # its embedded in the href, the for loop extracts it
        messages            = html_doc.xpath('//div[@class = "message-container"]/div[@class="message-top"]/a[contains(@href, "message.php")]')

        # gets the content of the posts
        contents            = html_doc.xpath('//td[@class = "message"]')

        # gets the first page of posts
        i = 0
        for p in posters
            poster      = p.text
            userid      = p["href"]
            userid      = userid.partition("=")[2]
            # gets the TC
            if(i==0) 
                t.tc = poster
            end

            timestamp   = timestamps[i].text
            timestamp   = timestamp.partition("Posted:")[2]
            timestamp   = timestamp.partition("|")[0]

            message_id  = messages[i]["href"]
            message_id  = message_id.partition("=")[2]
            message_id  = message_id.partition("&")[0]

            content     = contents[i].text

            post_number = (page - 1) * 50 + i
            t.posts[post_number]    =  Post.new(poster, userid, timestamp, message_id, post_number+1, content)
            i           += 1
        end
        return t
    end

    def extract_escape_characters input
        input = input.delete "\\"
        return input
    end
end
