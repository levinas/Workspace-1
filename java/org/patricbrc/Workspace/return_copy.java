package org.patricbrc.Workspace;

import java.io.*;
import java.util.*;
import org.codehaus.jackson.map.*;
import org.codehaus.jackson.map.annotate.*;
import org.codehaus.jackson.type.*;
import org.codehaus.jackson.*;



@JsonSerialize(using = return_copy_serializer.class)
@JsonDeserialize(using = return_copy_deserializer.class)
public class return_copy
{
    public List<ObjectMeta> output;
}


